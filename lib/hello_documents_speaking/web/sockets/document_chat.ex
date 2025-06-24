defmodule HelloDocumentsSpeaking.Sockets.DocumentChat do
  @moduledoc """
  WebSocket handler for real-time document chat functionality.

  This handler manages conversations between users and AI about specific documents.
  It provides asynchronous message processing where user messages appear immediately
  while AI responses are generated in the background.

  ## Protocol

  ### Initialization
  Clients must send an "init" message with document_ids to start a conversation.

  ### Message Flow
  1. User sends message -> immediately saved and echoed back
  2. AI processing starts asynchronously
  3. AI response is generated and sent back when ready

  """

  @behaviour WebSock
  import Ecto.Query
  require Logger
  alias HelloDocumentsSpeaking.Repo
  alias HelloDocumentsSpeaking.Models.{DocumentConversation, ConversationMessage, Document}
  alias HelloDocumentsSpeaking.Web.Utils.JsonUtils
  alias HelloDocumentsSpeaking.Services.DocumentAI

  def init(opts) do
    user = Map.get(opts, :user)
    {:ok, %{conversation: nil, user: user}}
  end

  @doc """
  Handles the initial message from the client, before conversation is created
  Function below handles subsequent messages
  """
  def handle_in({message, _}, %{conversation: nil, user: user} = state) do
    case JsonUtils.decode!(message) do
      %{"type" => "init", "document_ids" => document_ids} ->
        handle_init(user, document_ids, state)

      _ ->
        error_response = JsonUtils.encode!(%{error: "Invalid JSON format"})
        {:push, {:text, error_response}, state}
    end
  rescue
    _ ->
      error_response = JsonUtils.encode!(%{error: "Invalid JSON format"})
      {:push, {:text, error_response}, state}
  end

  def handle_in({message, _}, %{conversation: conversation, user: _user} = state) do
    case JsonUtils.decode!(message) do
      %{"type" => "message", "content" => content} ->
        handle_chat_message(content, conversation, state)

      _ ->
        error_response = JsonUtils.encode!(%{error: "Invalid JSON format"})
        {:push, {:text, error_response}, state}
    end
  rescue
    _ ->
      error_response = JsonUtils.encode!(%{error: "Invalid JSON format"})
      {:push, {:text, error_response}, state}
  end

  # Catch-all for any unmatched handle_in calls
  def handle_in({message, _}, state) do
    IO.puts("Unmatched message received: #{inspect(message)}")
    IO.puts("Current state: #{inspect(state)}")
    error_response = JsonUtils.encode!(%{error: "Unknown message format or invalid state"})
    {:push, {:text, error_response}, state}
  end

  defp handle_init(user, document_ids, state) do
    conversation =
      from(dc in DocumentConversation,
        where:
          dc.user_id == ^user.id and
            dc.document_ids == ^document_ids,
        preload: [:conversation_messages]
      )
      |> Repo.one()

    {conversation, is_new_conversation} =
      case conversation do
        nil ->
          new_conv = create_conversation(user, document_ids)
          {new_conv, true}

        existing_conv ->
          {existing_conv, false}
      end

    if is_new_conversation do
      send(self(), {:send_initial_ai_greeting, conversation.id, document_ids})
    end

    response =
      JsonUtils.encode!(%{
        type: "conversation_initialized",
        conversation: %{
          id: conversation.id,
          document_ids: conversation.document_ids,
          conversation_messages:
            conversation.conversation_messages
            |> Enum.sort_by(& &1.created_at, NaiveDateTime)
            |> format_messages()
        }
      })

    {:push, {:text, response}, %{state | conversation: conversation}}
  end

  defp handle_chat_message(content, conversation, state) do
    # we add the users message first for responsive chat feedback
    {:ok, user_message} =
      %ConversationMessage{}
      |> ConversationMessage.changeset(%{
        content: content,
        role: ConversationMessage.string_to_role("user"),
        document_conversation_id: conversation.id
      })
      |> Repo.insert()

    # and then send the user's message back immediately, to show in the client
    user_msg_response =
      JsonUtils.encode!(%{
        type: "message_saved",
        message: format_message(user_message)
      })

    # and then ayncronously generate the ai response
    send(self(), {:process_ai_response, conversation.id, state.user})

    {:push, {:text, user_msg_response}, state}
  end

  def handle_info({:process_ai_response, conversation_id, user}, state) do
    try do
      conversation =
        Repo.get(DocumentConversation, conversation_id) |> Repo.preload(:conversation_messages)

      if conversation do
        documents = load_documents(conversation.document_ids, user)
        documents_text = DocumentAI.prepare_text_for_analysis(documents)

        messages = DocumentAI.prepare_messages(conversation, documents_text)

        nil_messages =
          Enum.with_index(messages) |> Enum.filter(fn {msg, _idx} -> is_nil(msg[:content]) end)

        if length(nil_messages) > 0 do
          Logger.warning("Found #{length(nil_messages)} messages with nil content:")
        end

        ai_response =
          HelloDocumentsSpeaking.Clients.OpenAIClient.responses(
            DocumentAI.get_model_instructions(),
            messages,
            user: user,
            ai_processable: nil,
            type: :document
          )

        {:ok, ai_message} =
          %ConversationMessage{}
          |> ConversationMessage.changeset(%{
            content: ai_response,
            role: ConversationMessage.string_to_role("assistant"),
            document_conversation_id: conversation.id
          })
          |> Repo.insert()

        ai_response_json =
          JsonUtils.encode!(%{
            type: "ai_response",
            message: format_message(ai_message)
          })

        {:push, {:text, ai_response_json}, state}
      else
        {:ok, state}
      end
    rescue
      e ->
        Logger.error("Error processing AI response: #{inspect(e)}")

        error_response =
          JsonUtils.encode!(%{
            type: "error",
            error: "Failed to generate AI response"
          })

        {:push, {:text, error_response}, state}
    end
  end

  def handle_info({:send_initial_ai_greeting, conversation_id, document_ids}, state) do
    user = state.user

    documents = load_documents(document_ids, user)

    case DocumentAI.send_initial_greeting(conversation_id, documents, user) do
      {:ok, ai_message} ->
        response =
          JsonUtils.encode!(%{
            type: "ai_response",
            message: format_message(ai_message)
          })

        {:push, {:text, response}, state}

      {:error, _} ->
        # if ai greeting fails, just continue without it
        {:ok, state}
    end
  end

  def handle_info(message, state) do
    # we get some info messages just for normal processes.
    # good to log for debugging, but usually harmless
    # for example, when the mupdf parsing process closes, we get an :EXIT message
    Logger.debug("Received info: #{inspect(message)}")
    {:ok, state}
  end

  def terminate(reason, _state) do
    # this is needed by the behavior, but will just log it for now and return :ok
    IO.puts("WebSocket connection closed: #{inspect(reason)}")
    :ok
  end

  defp create_conversation(user, document_ids) do
    {:ok, conversation} =
      %DocumentConversation{}
      |> DocumentConversation.changeset(%{
        user_id: user.id,
        document_ids: document_ids
      })
      |> Repo.insert()

    conversation |> Repo.preload(:conversation_messages)
  end

  defp format_messages(messages) do
    Enum.map(messages, &format_message/1)
  end

  defp format_message(message) do
    %{
      id: message.id,
      content: message.content,
      role: ConversationMessage.role_to_string(message.role),
      timestamp: message.created_at |> NaiveDateTime.to_iso8601()
    }
  end

  defp load_documents(document_ids, user) when is_list(document_ids) do
    from(d in Document,
      where: d.id in ^document_ids and d.user_id == ^user.id,
      where: is_nil(d.deleted_at)
    )
    |> Repo.all()
  end

  defp load_documents(_, _), do: []
end

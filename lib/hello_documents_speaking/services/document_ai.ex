defmodule HelloDocumentsSpeaking.Services.DocumentAI do
  @moduledoc """
  Document AI Assistant service for analyzing documents and handling chat conversations.

  This module provides functionality to:
  - Analyze single or multiple documents using AI
  - Manage document conversation history
  - Send chat messages with AI responses

  Follows Elixir context patterns as the equivalent of Rails service objects.
  """

  import Ecto.Query
  alias HelloDocumentsSpeaking.Repo
  alias HelloDocumentsSpeaking.Models.{DocumentConversation, ConversationMessage, Document, User}
  alias HelloDocumentsSpeaking.Clients.OpenAIClient
  alias HelloDocumentsSpeaking.Services.PDFExtractor

  require Logger

  @model_instructions """
  You are a document assistant. Your job is to analyze the document(s) and provide insights.
  - Provide clear and concise analysis
  - Focus on important details and key information
  - Highlight any potential issues or considerations
  - Be brief in your responses
  - If the user corrects you or tells you it's made a mistake, then first think through the issue carefully before acknowledging the user, since users sometimes make errors themselves.
  - Never start your response by saying a question or idea or observation was good, great, fascinating, profound, excellent, or any other positive adjective. It skips the flattery and responds directly.
  """

  @doc """
  Returns the model instructions for public access.
  """
  def get_model_instructions, do: @model_instructions

  @doc """
  Analyzes a single document with a query.

  ## Parameters
  - `document`: Document struct to analyze
  - `query`: String question/prompt about the document
  - `user`: User making the request
  - `firm`: Firm context for the request

  ## Returns
  String response from AI analysis.
  """
  def analyze_document(%Document{} = document, query, %User{} = user)
      when is_binary(query) do
    document_text = extract_text_from_document(document)

    initial_message = %{
      role: "developer",
      content: "Here is the document text to analyze:\n\n#{document_text}\n\n"
    }

    messages = [initial_message, %{role: "user", content: query}]

    OpenAIClient.responses(
      @model_instructions,
      messages,
      user: user,
      ai_processable: document,
      type: :document
    )
  end

  @doc """
  Analyzes multiple documents with a query.

  ## Parameters
  - `documents`: List of Document structs to analyze
  - `query`: String question/prompt about the documents
  - `user`: User making the request
  - `firm`: Firm context for the request

  ## Returns
  String response from AI analysis.
  """
  def analyze_documents(documents, query, %User{} = user)
      when is_list(documents) and is_binary(query) do
    pdfs = Enum.filter(documents, &Document.is_pdf?/1)

    if Enum.empty?(pdfs) do
      "No PDF documents found to analyze."
    else
      combined_text =
        pdfs
        |> Enum.map(&prepare_document_text/1)
        |> Enum.join()

      initial_message = %{
        role: "developer",
        content: "Here is the document text to analyze:\n\n#{combined_text}\n\n"
      }

      messages = [initial_message, %{role: "user", content: query}]

      OpenAIClient.responses(
        @model_instructions,
        messages,
        user: user,
        ai_processable: nil,
        type: :document
      )
    end
  end

  @doc """
  Sends a chat message in an existing conversation and generates AI response.

  ## Parameters
  - `conversation_id`: ID of the DocumentConversation
  - `message`: User's message content
  - `documents`: List of documents in scope for this conversation
  - `user`: User sending the message
  - `firm`: Firm context

  ## Returns
  - `{:ok, conversation}` on success
  - `{:error, reason}` on failure

  """
  def send_chat_message(conversation_id, message, documents, %User{} = user)
      when is_binary(message) and is_list(documents) do
    case get_conversation(conversation_id, user) do
      nil ->
        {:error, "Conversation not found"}

      conversation ->
        {:ok, _} = add_message_to_conversation(conversation, message, "user")

        messages =
          documents
          |> prepare_text_for_analysis
          |> prepare_messages(conversation)

        ai_response =
          OpenAIClient.responses(
            @model_instructions,
            messages,
            user: user,
            ai_processable: nil,
            type: :document
          )

        {:ok, _} =
          add_message_to_conversation(conversation, ai_response, "assistant")

        updated_conversation =
          conversation
          |> Repo.preload(:conversation_messages, force: true)

        {:ok, updated_conversation}
    end
  end

  @doc """
  Sends an initial AI greeting for a new conversation.

  ## Parameters
  - `conversation_id`: ID of the DocumentConversation
  - `documents`: List of documents in scope for this conversation
  - `user`: User context
  - `firm`: Firm context

  ## Returns
  - `{:ok, ai_message}` on success
  - `{:error, reason}` on failure
  """
  def send_initial_greeting(conversation_id, documents, %User{} = user)
      when is_list(documents) do
    case get_conversation(conversation_id, user) do
      nil ->
        {:error, "Conversation not found"}

      conversation ->
        greeting_content = generate_greeting_content(documents)

        {:ok, ai_message} =
          add_message_to_conversation(conversation, greeting_content, "assistant")

        {:ok, ai_message}
    end
  end

  @doc """
  Gets conversation history for a given conversation ID.

  ## Parameters
  - `conversation_id`: ID of the DocumentConversation
  - `firm`: Firm context for authorization

  ## Returns
  - `{:ok, conversation_data}` with formatted conversation history
  - `{:error, reason}` if conversation not found
  """
  def get_conversation_history(conversation_id, %User{} = user) do
    case get_conversation(conversation_id, user) do
      nil ->
        {:error, "Conversation not found"}

      conversation ->
        conversation_data = %{
          conversation_id: conversation.id,
          document_ids: conversation.document_ids,
          messages: format_messages_for_api(conversation.conversation_messages),
          created_at: conversation.created_at
        }

        {:ok, conversation_data}
    end
  end

  # private

  defp get_conversation(conversation_id, %User{} = user) do
    from(dc in DocumentConversation,
      where: dc.id == ^conversation_id and dc.user_id == ^user.id,
      preload: [:conversation_messages]
    )
    |> Repo.one()
  end

  defp add_message_to_conversation(conversation, content, role) do
    role_enum = ConversationMessage.string_to_role(role)

    %ConversationMessage{}
    |> ConversationMessage.changeset(%{
      content: content,
      role: role_enum,
      document_conversation_id: conversation.id
    })
    |> Repo.insert()
  end

  defp extract_text_from_document(%Document{} = document) do
    cond do
      Document.is_folder?(document) ->
        ""

      Document.is_pdf?(document) ->
        extract_text_from_pdf(document)

      true ->
        # For non-PDF documents, try to read file directly
        try do
          Document.read_file(document)
        rescue
          e ->
            Logger.error("Failed to read document #{document.id}: #{inspect(e)}")
            ""
        end
    end
  end

  defp extract_text_from_pdf(%Document{} = document) do
    Logger.info("Extracting text from PDF document: #{document.name}")

    try do
      file_content = Document.read_file(document)

      extracted_text = PDFExtractor.extract_text_from_binary(file_content)

      if String.trim(extracted_text) == "" do
        Logger.error("PDF extraction returned empty text")
        file_content
      else
        extracted_text
      end
    rescue
      e ->
        Logger.error("Failed to extract PDF text from document #{document.id}: #{inspect(e)}")
        ""
    end
  end

  defp prepare_document_text(%Document{} = document) do
    text = extract_text_from_document(document)

    if String.trim(text) == "" do
      "Document: #{document.name} (#{document.file_content_type || "unknown type"})\n[Text extraction failed - file may be corrupted]\n\n---\n\n"
    else
      "Document: #{document.name}\n\n#{text}\n\n---\n\n"
    end
  end

  @doc """
  Prepares text for analysis from a list of documents.
  """
  def prepare_text_for_analysis(documents) when is_list(documents) do
    document_texts =
      documents
      |> Enum.map(&prepare_document_text/1)

    Enum.join(document_texts)
  end

  @doc """
  Prepares messages for OpenAI from conversation history and document text.
  """
  def prepare_messages(document_text, conversation) do
    conversation_messages =
      conversation.conversation_messages
      |> Enum.sort_by(& &1.created_at, NaiveDateTime)
      |> Enum.map(fn message ->
        %{
          role: ConversationMessage.role_to_string(message.role),
          content: message.content
        }
      end)

    initial_message = %{
      role: "developer",
      content: "Here is the document text to analyze:\n\n#{document_text}\n\n"
    }

    [initial_message | conversation_messages]
  end

  defp format_messages_for_api(messages) do
    messages
    |> Enum.sort_by(& &1.created_at, NaiveDateTime)
    |> Enum.map(fn message ->
      %{
        id: message.id,
        role: ConversationMessage.role_to_string(message.role),
        content: message.content,
        created_at: message.created_at
      }
    end)
  end

  defp generate_greeting_content(documents) do
    document_names =
      documents
      |> Enum.map(& &1.name)
      |> Enum.join(", ")

    if Enum.empty?(documents) do
      "Hello! I'm ready to help you analyze documents. Please upload some documents to get started."
    else
      "Hello! I can see you have #{length(documents)} document(s): #{document_names}. \
      I'll be glad to help you with them. What would you like to know?"
    end
  end
end

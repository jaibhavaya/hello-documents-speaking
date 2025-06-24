defmodule HelloDocumentsSpeaking.Clients.OpenAIClient do
  @moduledoc """
  OpenAI API client for generating responses using GPT models.
  Handles authentication, request formatting, and response parsing.
  """

  require Logger

  @base_url "https://api.openai.com/v1"
  @default_model "gpt-4.1"
  @default_max_tokens 1000
  @default_temperature 0.6

  @doc """
  Generate a response from OpenAI given system instructions and messages.

  ## Parameters
  - `system_instructions`: String containing the system prompt/instructions
  - `messages`: List of message maps with :role and :content keys
  - `opts`: Keyword list of options including:
    - `:user` - User model for tracking/billing
    - `:ai_processable` - Resource being processed (for tracking)
    - `:type` - Type of AI operation (e.g., :document)
    - `:model` - OpenAI model to use (default: gpt-4)
    - `:max_tokens` - Maximum response tokens
    - `:temperature` - Response creativity (0.0-1.0)

  ## Returns
  String response from OpenAI or error message.
  """
  def responses(system_instructions, messages, opts \\ []) do
    api_key = get_api_key()

    if is_nil(api_key) or api_key == "" do
      Logger.error("OpenAI API key not configured")
      "AI service temporarily unavailable"
    else
      model = Keyword.get(opts, :model, @default_model)
      max_tokens = Keyword.get(opts, :max_tokens, @default_max_tokens)
      temperature = Keyword.get(opts, :temperature, @default_temperature)

      formatted_messages = format_messages(system_instructions, messages)

      user = Keyword.get(opts, :user)
      user_id = if user, do: "lm-user-#{user.id}", else: nil

      request_body = %{
        model: model,
        messages: formatted_messages,
        max_tokens: max_tokens,
        temperature: temperature,
        # number of chat completion choices to generate
        n: 1
      }

      request_body = if user_id, do: Map.put(request_body, :user, user_id), else: request_body

      case make_request("/chat/completions", request_body, api_key) do
        {:ok, response} ->
          extract_response_content(response)

        {:error, error} ->
          Logger.error("OpenAI API error: #{inspect(error)}")
          "AI service temporarily unavailable"
      end
    end
  end

  defp get_api_key do
    Application.get_env(:goose, :openai_api_key)
  end

  defp format_messages(system_instructions, messages) do
    system_message = %{role: "system", content: system_instructions}

    formatted_with_index =
      messages
      |> Enum.map(&format_message/1)
      |> Enum.with_index()

    formatted_user_messages =
      formatted_with_index
      |> Enum.map(fn {msg, _idx} -> msg end)
      |> Enum.filter(& &1)

    final_messages = [system_message | formatted_user_messages]

    Enum.with_index(final_messages)
    |> Enum.each(fn {msg, idx} ->
      IO.puts(
        "  #{idx}: role=#{msg.role}, content=#{if msg.content, do: "present (#{String.length(msg.content)} chars)", else: "NIL"}"
      )
    end)

    final_messages
  end

  defp format_message(%{role: role, content: content}) do
    openai_role =
      case role do
        "developer" -> "system"
        "user" -> "user"
        "system" -> "assistant"
        "assistant" -> "assistant"
        _ -> "user"
      end

    %{role: openai_role, content: content}
  end

  defp format_message(message) when is_map(message) do
    role = message["role"] || message[:role]
    content = message["content"] || message[:content]

    if role && content do
      format_message(%{role: role, content: content})
    else
      nil
    end
  end

  defp format_message(_), do: nil

  defp make_request(endpoint, body, api_key) do
    url = @base_url <> endpoint

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    json_body = Jason.encode!(body)

    options = [
      timeout: 120_000,
      recv_timeout: 120_000,
      connect_timeout: 10_000
    ]

    case HTTPoison.post(url, json_body, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, _} -> {:error, "Invalid JSON response"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        Logger.error("OpenAI API returned status #{status_code}: #{response_body}")
        {:error, "API request failed with status #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  defp extract_response_content(%{"choices" => [%{"message" => %{"content" => content}} | _]}) do
    content
  end

  defp extract_response_content(%{"error" => %{"message" => error_message}}) do
    Logger.error("OpenAI API error: #{error_message}")
    "AI service error: #{error_message}"
  end

  defp extract_response_content(response) do
    Logger.error("Unexpected OpenAI response format: #{inspect(response)}")
    "AI service temporarily unavailable"
  end
end

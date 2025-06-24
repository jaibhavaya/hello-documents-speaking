# Best Practices

This document outlines development best practices for the Goose service.

## Adding New WebSocket Handlers

Goose is designed to support multiple WebSocket-based features. Follow this pattern to add new handlers:

### 1. Create the Handler File

Create your handler in the `web/sockets/` directory:

```elixir
# lib/goose/web/sockets/task_chat_socket.ex
defmodule Goose.Web.Sockets.TaskChatSocket do
  @moduledoc """
  WebSocket handler for task-related chat functionality.
  
  Handles real-time communication between users and AI for task management.
  """
  
  @behaviour WebSock
  import Ecto.Query
  require Logger
  
  alias Goose.Repo
  alias Goose.Models.{Task, User}
  alias Goose.Web.Utils.JsonUtils
  alias Goose.Services.TaskAI
  
  def init(opts) do
    user = Map.get(opts, :user)
    {:ok, %{task: nil, user: user}}
  end
  
  def handle_in({message, _}, state) do
    case JsonUtils.decode!(message) do
      %{"type" => "init", "task_id" => task_id} ->
        handle_init(task_id, state)
        
      %{"type" => "message", "content" => content} ->
        handle_message(content, state)
        
      _ ->
        error_response = JsonUtils.encode!(%{error: "Invalid message format"})
        {:push, {:text, error_response}, state}
    end
  rescue
    _ ->
      error_response = JsonUtils.encode!(%{error: "Invalid JSON format"})
      {:push, {:text, error_response}, state}
  end
  
  # Add handle_info/2 for async processing
  def handle_info({:process_ai_response, task_id, content, user}, state) do
    # Async AI processing logic here
    {:ok, state}
  end
  
  def terminate(reason, _state) do
    Logger.debug("Task chat WebSocket closed: #{inspect(reason)}")
    :ok
  end
  
  # Private helper functions...
end
```

### 2. Add the Route

Add the WebSocket route to the authenticated router:

```elixir
# lib/goose/web/authenticated_router.ex
defmodule Goose.Web.AuthenticatedRouter do
  # ... existing code ...
  
  # Task Chat WebSocket - AI-powered task management
  get "/task-chat" do
    current_user = conn.assigns.current_user
    
    conn
    |> WebSockAdapter.upgrade(Goose.Web.Sockets.TaskChatSocket, %{user: current_user}, timeout: 60_000)
    |> halt()
  end
  
  # ... rest of routes ...
end
```

### 3. Follow the Async Pattern

For the best user experience, implement asynchronous processing:

1. **Save user messages immediately** and echo back to client
2. **Process AI/business logic asynchronously** using `send(self(), ...)`
3. **Send results when ready** via `handle_info/2`
4. **Handle errors gracefully** to prevent WebSocket crashes

```elixir
defp handle_message(content, state) do
  # 1. Save user message immediately
  {:ok, user_message} = save_user_message(content, state)
  
  # 2. Echo back to client for instant feedback
  response = JsonUtils.encode!(%{
    type: "message_saved",
    message: format_message(user_message)
  })
  
  # 3. Process asynchronously
  send(self(), {:process_ai_response, state.task.id, content, state.user})
  
  {:push, {:text, response}, state}
end
```

### 4. Error Handling

Always include comprehensive error handling:

```elixir
def handle_info({:process_ai_response, task_id, content, user}, state) do
  try do
    # Your async processing logic
    ai_response = process_with_ai(task_id, content, user)
    
    response = JsonUtils.encode!(%{
      type: "ai_response",
      message: ai_response
    })
    
    {:push, {:text, response}, state}
  rescue
    e ->
      Logger.error("Error processing AI response: #{inspect(e)}")
      
      error_response = JsonUtils.encode!(%{
        type: "error", 
        error: "Failed to process request"
      })
      
      {:push, {:text, error_response}, state}
  end
end
```

## Code Organization Guidelines

### Module Placement

- **External API Clients** → `lib/goose/clients/`
- **Data Models** → `lib/goose/models/`
- **Business Logic & Services** → `lib/goose/services/`
- **Web Layer** → `lib/goose/web/` (auth, routers, sockets, utils)
- **WebSocket Handlers** → `lib/goose/web/sockets/`

### Naming Conventions

- **WebSocket modules**: `Goose.Web.Sockets.FeatureChatSocket`
- **Service modules**: `Goose.Services.FeatureService` 
- **Client modules**: `Goose.Clients.ExternalServiceClient`
- **Model modules**: `Goose.Models.ModelName`

### JSON API Consistency

Always use `JsonUtils` for WebSocket responses to ensure camelCase conversion:

```elixir
# ✅ Good - Converts snake_case to camelCase
response = JsonUtils.encode!(%{user_id: 1, first_name: "John"})
# Sends: {"userId": 1, "firstName": "John"}

# ❌ Bad - No case conversion
response = Jason.encode!(%{user_id: 1, first_name: "John"}) 
# Sends: {"user_id": 1, "first_name": "John"}
```

## Testing WebSocket Handlers

### Manual Testing with wscat

```bash
# Install wscat
npm install -g wscat

# Connect to your handler
wscat -c "ws://localhost:4000/api/task-chat" \
       -H "Authorization: Bearer YOUR_TOKEN"

# Send test messages
{"type": "init", "taskId": 1}
{"type": "message", "content": "What is the status of this task?"}
```

### Integration Tests

Create integration tests for your WebSocket handlers:

```elixir
# test/websockets/task_chat_websocket_test.exs
defmodule Goose.WebSockets.TaskChatWebSocketTest do
  use ExUnit.Case
  
  # Test WebSocket connections and message handling
end
```

## Performance Considerations

- **Use async processing** for AI calls to avoid blocking the WebSocket
- **Implement proper timeouts** for external API calls
- **Add circuit breakers** for unreliable external services
- **Monitor memory usage** for long-running WebSocket connections
- **Implement rate limiting** if needed to prevent abuse

## Security Best Practices

- **Always validate JWT tokens** via the Auth plug
- **Sanitize user input** before processing
- **Log security events** for monitoring
- **Use HTTPS/WSS** in production
- **Implement proper CORS** configuration
- **Never log sensitive information** (tokens, API keys, user data)
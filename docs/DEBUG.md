# Debug Guide

This guide helps developers debug issues in the Hello Documents Speaking service effectively.

## Local Development Setup

### Starting the Service

```bash
# Start the service with console output
mix run --no-halt

# Start with interactive shell for debugging
iex -S mix
```

### Useful IEx Commands

```elixir
# Check if the application is running
:application.which_applications()

# Inspect a specific module
i(HelloDocumentsSpeaking.WebSockets.DocumentChatWebSocket)

# Check process status
Process.list() |> length()

# Test database connection
HelloDocumentsSpeaking.Repo.query("SELECT 1")

# Test document loading
document = HelloDocumentsSpeaking.Repo.get(HelloDocumentsSpeaking.Models.Document, 1)
HelloDocumentsSpeaking.Models.Document.read_file(document)

# Test OpenAI client
HelloDocumentsSpeaking.Clients.OpenAIClient.responses("You are helpful", [%{role: "user", content: "Hello"}])
```

## Common Debugging Scenarios

### WebSocket Connection Issues

#### Problem: WebSocket won't connect

**Check these:**

1. **Authentication token**:
```bash
# Test token validity
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:4000/health
```

2. **Server status**:
```bash
# Check if server is running
curl http://localhost:4000/health
# Should return: {"status": "ok"}
```

3. **WebSocket upgrade**:
```bash
# Test WebSocket connection
wscat -c "ws://localhost:4000/api/document-chat" \
       -H "Authorization: Bearer YOUR_TOKEN"
```

#### Problem: WebSocket connects but messages fail

**Debug steps:**

1. **Check message format**:
```json
// Correct initialization
{"type": "init", "document_ids": [1], "prospect_id": 1}

// Correct chat message  
{"type": "message", "content": "What does this document say?"}
```

2. **Check server logs** for error messages

3. **Verify user permissions** - user must have access to documents

### Database Issues

#### Problem: Database connection errors

**Check:**

1. **Database is running**:
```bash
# Check PostgreSQL status
brew services list | grep postgresql
# or
sudo service postgresql status
```

2. **Connection settings** in `.env`:
```bash
DATABASE_NAME=boost_development
DATABASE_USER=your_db_user
DATABASE_PASSWORD=your_db_password
DATABASE_HOST=localhost
DATABASE_PORT=5432
```

3. **Test connection**:
```bash
# In iex -S mix
HelloDocumentsSpeaking.Repo.query("SELECT version()")
```

#### Problem: Records not found

**Debug in IEx:**

```elixir
# Check if user exists
user = HelloDocumentsSpeaking.Repo.get(HelloDocumentsSpeaking.Models.User, 1)

# Check if documents exist  
docs = HelloDocumentsSpeaking.Repo.all(HelloDocumentsSpeaking.Models.Document)

# Check firm association
user = HelloDocumentsSpeaking.Repo.preload(user, :current_firm)
```

### AI/OpenAI Issues

#### Problem: AI responses failing

**Check these:**

1. **API key configuration**:
```elixir
# In iex -S mix
System.get_env("OPENAI_API_KEY")
Application.get_env(:hello-documents-speaking, :openai_api_key)
```

2. **Rate limits and quotas** in OpenAI dashboard

3. **Request format**:
```elixir
# Test minimal request
HelloDocumentsSpeaking.Clients.OpenAIClient.responses(
  "You are helpful", 
  [%{role: "user", content: "Hello"}]
)
```

4. **Network connectivity**:
```bash
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer YOUR_API_KEY"
```

#### Problem: Document text extraction failing

**Debug steps:**

1. **Check MuPDF installation**:
```bash
which mutool
mutool --version
```

2. **Test PDF extraction**:
```elixir
# In iex -S mix
document = HelloDocumentsSpeaking.Repo.get(HelloDocumentsSpeaking.Models.Document, 1)
HelloDocumentsSpeaking.Services.PDFExtractor.extract_text_from_binary(file_content)
```

3. **Check S3 access**:
```elixir
# Test S3 file reading
document = HelloDocumentsSpeaking.Repo.get(HelloDocumentsSpeaking.Models.Document, 1) 
HelloDocumentsSpeaking.Models.Document.read_file(document)
```

### S3 Issues

#### Problem: S3 file access errors

**Check configuration:**

1. **Environment variables**:
```bash
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY  
echo $AWS_REGION
echo $AWS_S3_BUCKET
```

2. **Bucket permissions** - ensure read access

3. **File exists in S3**:
```bash
aws s3 ls s3://your-bucket/store/
```

4. **Test S3 access**:
```elixir
# In iex -S mix
ExAws.S3.list_objects("your-bucket") |> ExAws.request()
```

## Debugging Tools

### Logging

Add debug logging strategically:

```elixir
require Logger

def handle_in({message, _}, state) do
  Logger.debug("Received WebSocket message: #{inspect(message)}")
  Logger.debug("Current state: #{inspect(state)}")
  
  # Your logic here
end
```

### IEx Debugging

Add breakpoints in your code:

```elixir
def some_function(data) do
  require IEx; IEx.pry()  # Breakpoint
  # Process data
end
```

### Process Inspection

Monitor processes and memory:

```elixir
# List all processes
Process.list()

# Check specific process
pid = Process.whereis(HelloDocumentsSpeaking.Repo)
Process.info(pid)

# Monitor memory usage
:observer.start()
```

## Performance Debugging

### Slow WebSocket Responses

1. **Check AI processing time** - add timing logs
2. **Database query performance** - use `Ecto.Query` debugging
3. **S3 file access time** - add timing around file reads

### Memory Issues

1. **Monitor process memory**:
```elixir
Process.info(self(), :memory)
```

2. **Check for memory leaks** in long-running WebSocket connections

3. **Use Observer** for system-wide monitoring:
```elixir
:observer.start()
```

## Environment-Specific Issues

### Development Environment

- **Port conflicts**: Change port in config if 4000 is taken
- **Database seeds**: Ensure test data exists
- **CORS issues**: Check `cors_config.ex` for localhost origins

### Production Environment

- **Environment variables**: Verify all required vars are set
- **SSL/TLS**: Ensure proper certificate configuration  
- **Resource limits**: Check memory and CPU constraints
- **External service access**: Verify network access to OpenAI/S3

## Troubleshooting Checklist

When debugging an issue, work through this checklist:

### ✅ Basic Checks
- [ ] Service is running (`curl localhost:4000/health`)
- [ ] Database is accessible
- [ ] Required environment variables are set
- [ ] No compilation errors (`mix compile`)

### ✅ Authentication  
- [ ] JWT token is valid
- [ ] User exists in database
- [ ] User has required permissions

### ✅ WebSocket Specific
- [ ] Message format is correct
- [ ] WebSocket connection successful
- [ ] No errors in server logs

### ✅ External Services
- [ ] OpenAI API key is valid
- [ ] S3 credentials and permissions correct
- [ ] MuPDF tools installed
- [ ] Network connectivity to external services

### ✅ Data Issues
- [ ] Required records exist in database
- [ ] Document files exist in S3
- [ ] Data relationships are correct

## Getting Help

If you're still stuck after working through this guide:

1. **Check the logs** for specific error messages
2. **Search issues** in the repository  
3. **Ask team members** who are familiar with the codebase
4. **Create a minimal reproduction** case
5. **Document the issue** with steps to reproduce
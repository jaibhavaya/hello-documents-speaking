defmodule HelloDocumentsSpeaking.Application do
  use Application

  def start(_type, _args) do
    IO.puts("Starting the machine... on port 4000...")

    children = [
      HelloDocumentsSpeaking.Repo,
      {Bandit, plug: HelloDocumentsSpeaking.Router, port: 4000}
    ]

    opts = [strategy: :one_for_one, name: HelloDocumentsSpeaking.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule HelloDocumentsSpeaking.Router do
  use Plug.Router

  plug(Plug.Logger)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)

  plug(Corsica,
    origins: HelloDocumentsSpeaking.Web.Utils.CorsConfig.origins(),
    allow_credentials: true,
    allow_headers: ["access-token", "uid", "client", "content-type", "accept"],
    allow_methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
  )

  plug(:match)
  plug(:dispatch)

  get "/health" do
    send_resp(conn, 200, Jason.encode!(%{status: "ok"}))
  end

  forward("/api", to: HelloDocumentsSpeaking.Web.AuthenticatedRouter)

  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
  end
end

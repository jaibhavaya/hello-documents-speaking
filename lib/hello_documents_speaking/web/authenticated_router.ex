defmodule HelloDocumentsSpeaking.Web.AuthenticatedRouter do
  @moduledoc """
  Authenticated routes that require JWT token validation.

  All routes here are protected by HelloDocumentsSpeaking.Web.Utils.Auth which validates
  Bearer tokens and loads the current user.
  """

  use Plug.Router

  plug(HelloDocumentsSpeaking.Web.Auth)
  plug(:match)
  plug(:dispatch)

  get "/document-chat" do
    current_user = conn.assigns.current_user

    conn
    |> WebSockAdapter.upgrade(HelloDocumentsSpeaking.Web.Sockets.DocumentChat, %{user: current_user},
      timeout: 60_000
    )
    |> halt()
  end

  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
  end
end

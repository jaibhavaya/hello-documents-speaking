defmodule HelloDocumentsSpeaking.Web.Auth do
  import Plug.Conn
  alias HelloDocumentsSpeaking.Repo
  alias HelloDocumentsSpeaking.Models.User

  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    access_token =
      get_req_header(conn, "access-token") |> List.first() ||
        conn.query_params["access-token"]

    uid =
      get_req_header(conn, "uid") |> List.first() ||
        conn.query_params["uid"]

    client =
      get_req_header(conn, "client") |> List.first() ||
        conn.query_params["client"]

    if access_token && uid && client do
      verify_devise_headers(conn, access_token, uid, client)
    else
      Logger.error("Missing required auth credentials")
      unauthorized(conn)
    end
  end

  defp verify_devise_headers(conn, access_token, uid, client) do
    case User |> Repo.get_by(email: uid) do
      nil ->
        Logger.error("User not found: #{uid}")
        unauthorized(conn)

      user ->
        tokens =
          case user.tokens do
            nil ->
              %{}

            "" ->
              %{}

            json_string when is_binary(json_string) ->
              case Jason.decode(json_string) do
                {:ok, decoded} -> decoded
                {:error, _} -> %{}
              end

            map when is_map(map) ->
              map
          end

        case Map.get(tokens, client) do
          nil ->
            Logger.error("Client not found in user tokens")
            unauthorized(conn)

          token_data ->
            stored_token = token_data["token"] || token_data[:token]
            expiry = token_data["expiry"] || token_data[:expiry]

            current_time = System.system_time(:second)

            cond do
              !Bcrypt.verify_pass(access_token, stored_token) ->
                Logger.error("Access token mismatch (bcrypt verification failed)")
                unauthorized(conn)

              expiry && expiry < current_time ->
                Logger.info("Token expired")
                unauthorized(conn)

              true ->
                assign(conn, :current_user, user)
            end
        end
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: "Unauthorized"}))
    |> halt()
  end
end

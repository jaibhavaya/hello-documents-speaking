defmodule HelloDocumentsSpeaking.Web.Utils.CorsConfig do
  def origins do
    case System.get_env("ALLOWED_ORIGINS") do
      nil ->
        # for local dev
        ["http://localhost:3000", "http://localhost:8080"]

      origins_string ->
        # Production: comma-separated list of origins
        String.split(origins_string, ",")
        |> Enum.map(&String.trim/1)
    end
  end
end


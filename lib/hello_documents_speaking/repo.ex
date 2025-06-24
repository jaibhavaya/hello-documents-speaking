defmodule HelloDocumentsSpeaking.Repo do
  use Ecto.Repo,
    otp_app: :hello_documents_speaking,
    adapter: Ecto.Adapters.Postgres
end

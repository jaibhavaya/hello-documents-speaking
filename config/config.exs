import Config

# Set defaults here, runtime.exs will override with .env values
config :hello_documents_speaking, HelloDocumentsSpeaking.Repo,
  database: "boost_development",
  username: "postgres",
  password: "password",
  hostname: "localhost",
  port: 5432

config :hello_documents_speaking, ecto_repos: [HelloDocumentsSpeaking.Repo]

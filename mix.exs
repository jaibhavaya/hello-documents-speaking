defmodule HelloDocumentsSpeaking.MixProject do
  use Mix.Project

  def project do
    [
      app: :hello_documents_speaking,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :httpoison, :hackney],
      mod: {HelloDocumentsSpeaking.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.15"},
      {:bandit, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:websock_adapter, "~> 0.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      {:joken, "~> 2.6"},
      {:dotenvy, "~> 0.8"},
      {:corsica, "~> 2.0"},
      {:bcrypt_elixir, "~> 3.0"},
      {:httpoison, "~> 2.0"},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:hackney, "~> 1.9"}
    ]
  end
end

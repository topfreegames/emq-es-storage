defmodule EmqEsStorage.Mixfile do
  use Mix.Project

  def project do
    [
      app: :emq_es_storage,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      aliases: aliases(),
    ]
  end

  defp aliases do
    [
      test: "test --no-start",
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :tirexs, :redix, :cachex],
      mod: {EmqEsStorage, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tirexs, "~> 0.8"},
      {:redix, ">= 0.0.0"},
      {:cachex, "~> 2.1"},

      # TEST
      {:emqttd,
       github: "emqtt/emqttd",
       only: [:test],
       ref: "v2.3-beta.1",
       manager: :make,
       optional: true,
      },
      { :uuid, "~> 1.1", only: [:test]},
      # {:distillery, "~> 1.4", runtime: false},
    ]
  end
end

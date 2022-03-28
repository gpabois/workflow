defmodule Workflow.MixProject do
  use Mix.Project

  def project do
    [
      app: :workflow,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:oban, "~> 2.11"},
      {:phoenix, "~> 1.6.6"},
      {:ecto_sql, "~> 3.6"},
      {:postgrex, ">= 0.0.0"},
      {:jason, "~> 1.1"},
      {:faker, "~> 0.17", only: :test}
    ]
  end

  defp aliases do
    [
     test: ["ecto.create --quiet", "test"]
    ]
  end
end

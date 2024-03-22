defmodule Algolia.Mixfile do
  use Mix.Project

  def project do
    [
      app: :algolia,
      version: "0.8.0",
      description: "Elixir implementation of Algolia Search API",
      elixir: "~> 1.13",
      package: package(),
      deps: deps(),
      docs: [extras: ["README.md"], main: "readme"]
    ]
  end

  def package do
    [
      maintainers: ["Sikan He"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/sikanhe/algolia-elixir"}
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:hackney, "~> 1.9 or ~> 1.10"},
      {:tesla, "~> 1.5"},
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:jason, "~> 1.0"},
      {:styler, "~> 0.11", only: [:dev, :test], runtime: false},
      # Docs
      {:ex_doc, "~> 0.19", only: :dev},
      {:inch_ex, ">= 0.0.0", only: :dev}
    ]
  end
end

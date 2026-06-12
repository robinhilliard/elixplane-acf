defmodule XPlane.Acf.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/robinhilliard/elixplane-acf"

  def project do
    [
      app: :xplane_acf,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "elixplane_acf",
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Parse, edit and write X-Plane 11 .acf aircraft files (and the .afl airfoils " <>
      "they reference) with byte-exact round-trips and a semantic aircraft model."
  end

  defp package do
    [
      name: "elixplane_acf",
      files: ~w(lib mix.exs README.md LICENSE .formatter.exs),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["Robin Hilliard"]
    ]
  end

  defp docs do
    [
      main: "XPlane.Acf",
      source_url: @source_url,
      extras: ["README.md", "LICENSE"]
    ]
  end
end

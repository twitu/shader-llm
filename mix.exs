defmodule ShaderLlm.MixProject do
  use Mix.Project
  def project do
    [
      app: :shaderllm,
      version: "0.1.0",
      elixir: "~> 1.14",
      deps: deps()
    ]
  end

  def application do
    [
      mod: {ShaderLlm.Application, []},
      extra_applications: [:logger, :cors_plug]
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.6"},
      {:jason, "~> 1.4"},
      {:httpoison, "~> 2.0"},
      {:cors_plug, "~> 3.0"}
    ]
  end
end

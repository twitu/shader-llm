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
    [mod: {ShaderLlm.Application, []}]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.6"},
      {:jason, "~> 1.4"},
      {:httpoison, "~> 2.0"}
    ]
  end
end

defmodule ShaderLlm.MixProject do
  use Mix.Project

  def project do
    [
      app: :shaderllm,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      rustler_crates: [
        rust_calc: [
          path: "native/rust_calc",
          lib_name: "rust_calc",
          nif_file: "rust_calc",
          force_recompile: Mix.env() == :dev,
          load_on_start: true,
          mode: :release
        ]
      ]
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
      {:req, "~> 0.3"},
      {:cors_plug, "~> 3.0"},
      {:rustler, "~> 0.36.1"}
    ]
  end
end

defmodule ShaderLlm.RustCalc do
  use Rustler, otp_app: :shaderllm, crate: "rust_calc"

  # Fallback implementation. When the NIF is loaded, this function will be replaced by the Rust implementation.
  def calculate(input), do: :erlang.nif_error(:nif_not_loaded)
end

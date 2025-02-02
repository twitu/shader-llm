defmodule ShaderLlm.Application do
  use Application
  use Plug.Router
  require Logger

  plug :match
  plug Plug.Logger
  plug CORSPlug, origin: ["http://localhost:3000", "http://localhost:5173"]
  plug Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason
  plug :dispatch

  def start(_type, _args) do
    Logger.info("Starting ShaderLLM server on port 4000...")
    children = [
      {Plug.Cowboy, scheme: :http, plug: __MODULE__, options: [port: 4000]}
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end

  post "/api/generate_shader" do
    Logger.info("Received shader generation request: #{inspect(conn.body_params)}")
    case conn.body_params do
      %{"prompt" => "test shader"} ->
        Logger.info("Returning test shader")
        send_json(conn, 200, %{shader: get_test_shader()})

      %{"prompt" => prompt} ->
        case System.get_env("LLM_API_KEY") do
          nil ->
            Logger.error("LLM API key not configured")
            send_json(conn, 500, %{error: "API key not configured"})
          key ->
            Logger.info("Forwarding request to LLM")
            handle_llm_request(conn, prompt, key)
        end

      _ ->
        Logger.warn("Missing prompt in request")
        send_json(conn, 400, %{error: "Missing prompt"})
    end
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp send_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end

  defp handle_llm_request(conn, prompt, api_key) do
    case HTTPoison.post(
      "https://api.openai.com/v1/chat/completions",
      Jason.encode!(%{
        model: "gpt-4",
        messages: [
          %{role: "system", content: "Generate only valid GLSL shader code. Include version and precision."},
          %{role: "user", content: prompt}
        ]
      }),
      [
        {"Authorization", "Bearer #{api_key}"},
        {"Content-Type", "application/json"}
      ]
    ) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}} ->
            send_json(conn, 200, %{shader: content})
          _ ->
            send_json(conn, 500, %{error: "Invalid LLM response"})
        end
      _ ->
        send_json(conn, 500, %{error: "LLM request failed"})
    end
  end

  defp get_test_shader do
    """
    #version 300 es
    precision mediump float;
    out vec4 fragColor;
    void main() {
      vec2 uv = gl_FragCoord.xy/vec2(800, 600);
      fragColor = vec4(uv.x, uv.y, 0.5, 1.0);
    }
    """
  end
end

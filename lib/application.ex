defmodule ShaderLlm.Application do
  use Application
  use Plug.Router
  require Logger

  plug :match
  plug Plug.Logger
  # Support both local and production frontend URLs
  plug CORSPlug, origin: [
    "http://localhost:3000",
    "http://localhost:5173",
    "https://shader-llm.fly.dev"
  ]
  plug Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason
  plug :dispatch

  @claude_api_url "https://api.anthropic.com/v1/messages"

  def start(_type, _args) do
    # Use PORT env var in production, default to 4000 for local dev
    port = String.to_integer(System.get_env("PORT") || "4000")
    Logger.info("Starting ShaderLLM server on port #{port}...")

    children = [
      {Plug.Cowboy, scheme: :http, plug: __MODULE__, options: [port: port]}
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end

  post "/api/generate_shader" do
    Logger.info("Received shader generation request: #{inspect(conn.body_params)}")
    case conn.body_params do
      %{"prompt" => "test shader"} ->
        Logger.info("Returning test shader")
        send_json(conn, 200, %{shader_code: get_test_shader()})

      %{"prompt" => prompt} ->
        case System.get_env("CLAUDE_API_KEY") do
          nil ->
            Logger.error("Claude API key not configured")
            send_json(conn, 500, %{error: "API key not configured. Set CLAUDE_API_KEY environment variable."})
          api_key ->
            Logger.info("Forwarding request to Claude")
            handle_claude_request(conn, prompt, api_key)
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

  defp handle_claude_request(conn, prompt, api_key) do
    system_prompt = """
    You are a WebGL fragment shader expert. Generate fragment shaders based on the user's description.
    Follow these guidelines:

    1. Always start with these required declarations:
       precision mediump float;
       uniform vec2 resolution;  // canvas size
       uniform float time;      // time in seconds

    2. Use these variables in your shader:
       - vec2 uv = gl_FragCoord.xy/resolution.xy;  // normalized coordinates (0 to 1)
       - time for animations

    3. Output format must be:
       void main() {
         // your code here
         gl_FragColor = vec4(r, g, b, a);  // final color
       }

    4. Common patterns:
       - Use uv.x and uv.y for position-based effects
       - sin(time) for animations
       - mix() for color blending
       - length() for circular patterns
       - fract() for repeating patterns

    5. Avoid:
       - Complex 3D transformations
       - Custom functions (keep it in main)
       - Vertex shader modifications
       - External textures or samplers

    Return only the shader code, no explanations or markdown.
    """

    request_body = %{
      model: "claude-3-opus-20240229",
      max_tokens: 1000,
      system: system_prompt,
      messages: [
        %{
          role: "user",
          content: prompt
        }
      ]
    }

    headers = [
      {"x-api-key", api_key},
      {"anthropic-version", "2023-06-01"},
      {"content-type", "application/json"}
    ]

    # Add timeout options (30 seconds)
    options = [
      timeout: 30_000,
      recv_timeout: 30_000
    ]

    case HTTPoison.post(@claude_api_url, Jason.encode!(request_body), headers, options) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"content" => [%{"text" => shader_code} | _]}} ->
            # Clean up any potential markdown code blocks
            clean_code = shader_code
              |> String.replace("```glsl", "")
              |> String.replace("```", "")
              |> String.trim()
            send_json(conn, 200, %{shader_code: clean_code})
          _ ->
            Logger.error("Invalid Claude response format: #{inspect(body)}")
            send_json(conn, 500, %{error: "Invalid response from Claude"})
        end

      {:ok, %{status_code: status_code, body: body}} ->
        Logger.error("Claude API error: #{status_code} - #{inspect(body)}")
        send_json(conn, 500, %{error: "Claude API error: #{status_code}"})

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Claude API request failed: #{inspect(reason)}")
        send_json(conn, 500, %{error: "Failed to connect to Claude API"})
    end
  end

  defp get_test_shader do
    """
    precision mediump float;
    uniform vec2 resolution;
    uniform float time;

    void main() {
      vec2 uv = gl_FragCoord.xy/resolution.xy;
      vec3 color = 0.5 + 0.5 * cos(time + uv.xyx + vec3(0,2,4));
      gl_FragColor = vec4(color, 1.0);
    }
    """
  end
end

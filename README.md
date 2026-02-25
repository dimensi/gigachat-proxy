# GigaChat Proxy

OpenAI-compatible proxy for [GigaChat](https://developers.sber.ru/gigachat) — Russian LLM by Sber.

Wraps [gpt2giga](https://github.com/ai-forever/gpt2giga) in a one-command setup that works on macOS and Linux.

## What it does

Any tool or library that speaks **OpenAI API** (ChatGPT format) can talk to GigaChat without any code changes — just point it at `http://localhost:8090`.

```
Your app  →  OpenAI API format  →  [this proxy]  →  GigaChat API
```

Works with: Raycast AI, Cursor, Aider, Claude Code, LangChain, OpenAI SDK, and anything else that supports a custom `base_url`.

## Quick start

```bash
curl -fsSL https://dimensi.github.io/gigachat-proxy/setup.sh | bash
```

The script will:

1. Check if Docker is installed — installs it if missing (Homebrew on macOS, `get.docker.com` on Linux)
2. Wait for Docker daemon to be ready
3. Ask for your GigaChat authorization key (hidden input)
4. Create `~/gigachat-proxy/` with all config files
5. Pull and start the proxy container
6. Run a smoke test (health, models, chat, streaming)

Re-running the script is safe — it will offer to reuse the existing key and recreate the container.

## Requirements

- macOS or Ubuntu/Debian Linux
- GigaChat authorization key — get one at [developers.sber.ru/studio](https://developers.sber.ru/studio)
- Docker (installed automatically if missing)
- Python 3 (for the smoke test, optional)

## Manual setup

If you prefer to configure manually:

```bash
git clone https://github.com/dimensi/gigachat-proxy
cd gigachat-proxy
cp .env.example .env          # fill in your key
docker compose up -d
python3 test.py
```

## Configuration

Edit `~/gigachat-proxy/.env`:

| Variable | Description |
|---|---|
| `GIGACHAT_CREDENTIALS` | Your GigaChat authorization key |

Edit `~/gigachat-proxy/docker-compose.yml` to change advanced settings:

| Variable | Default | Description |
|---|---|---|
| `GIGACHAT_SCOPE` | `GIGACHAT_API_PERS` | API scope (`GIGACHAT_API_PERS` for personal, `GIGACHAT_API_CORP` for corporate) |
| `GPT2GIGA_MODE` | `DEV` | `DEV` enables `/docs` and log endpoints; `PROD` disables them |
| `GIGACHAT_TIMEOUT` | `60` | Request timeout in seconds |

## Using with OpenAI SDK

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://127.0.0.1:8090",
    api_key="dummy",  # any value works
)

response = client.chat.completions.create(
    model="GigaChat-2-Max",
    messages=[{"role": "user", "content": "Hello!"}],
)
print(response.choices[0].message.content)
```

## Using with Raycast AI

Add to your Raycast AI provider config:

```yaml
- id: gigachat
  name: GigaChat
  base_url: http://127.0.0.1:8090
  api_keys:
    gigachat: dummy
  models:
    - id: GigaChat-2-Max
      name: GigaChat 2 Max
      provider: gigachat
      context: 131072
      abilities:
        temperature: { supported: true }
        vision: { supported: true }
        system_message: { supported: true }
        tools: { supported: true }
```

## Available models

| Model | Context |
|---|---|
| GigaChat-2-Max | 131 072 tokens |
| GigaChat-2-Pro | 131 072 tokens |
| GigaChat-2 | 131 072 tokens |
| GigaChat-Max | 128 000 tokens |
| GigaChat-Pro | 32 768 tokens |

## Proxy endpoints

| Endpoint | Description |
|---|---|
| `POST /v1/chat/completions` | Chat completions (streaming supported) |
| `GET /v1/models` | List available models |
| `POST /v1/embeddings` | Text embeddings |
| `GET /health` | Health check |
| `GET /docs` | Swagger UI (DEV mode) |

## Managing the container

```bash
cd ~/gigachat-proxy

docker compose logs -f      # live logs
docker compose down         # stop
docker compose up -d        # start
docker compose restart      # restart
```

## License

MIT

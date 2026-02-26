# GigaChat Proxy

OpenAI-совместимый прокси для [GigaChat](https://developers.sber.ru/gigachat) — российской языковой модели от Сбера.

Оборачивает [gpt2giga](https://github.com/ai-forever/gpt2giga) в одну команду установки, которая работает на macOS и Linux.

## Зачем это нужно

Любой инструмент или библиотека, которые умеют работать с **OpenAI API** (формат ChatGPT), будут работать с GigaChat без изменений в коде — достаточно указать `http://localhost:8090` в качестве адреса API.

```
Ваше приложение  →  OpenAI API  →  [этот прокси]  →  GigaChat API
```

Работает с: Raycast AI, Cursor, Aider, Claude Code, LangChain, OpenAI SDK и любым другим инструментом с поддержкой кастомного `base_url`.

## Быстрый старт

```bash
curl -fsSL https://dimensi.github.io/gigachat-proxy/setup.sh | bash
```

Скрипт выполнит следующее:

1. Проверит наличие Docker — установит, если не найден (Homebrew на macOS, `get.docker.com` на Linux)
2. Дождётся запуска Docker daemon
3. Запросит ключ авторизации GigaChat (ввод скрыт)
4. Создаст директорию `~/gigachat-proxy/` со всеми конфигурационными файлами
5. Скачает и запустит контейнер прокси
6. Запустит smoke-тест (health, models, chat, streaming)

Повторный запуск безопасен — скрипт предложит оставить существующий ключ и пересоздаст контейнер.

## Требования

- macOS или Ubuntu/Debian Linux
- Ключ авторизации GigaChat — получить на [developers.sber.ru/studio](https://developers.sber.ru/studio)
- Docker (устанавливается автоматически при отсутствии)
- Python 3 (для smoke-теста, опционально)

## Ручная установка

Если предпочитаете настроить вручную:

```bash
git clone https://github.com/dimensi/gigachat-proxy
cd gigachat-proxy
cp .env.example .env          # вставьте ваш ключ
docker compose up -d
python3 test.py
```

## Настройка

Редактировать `~/gigachat-proxy/.env`:

| Переменная | Описание |
|---|---|
| `GIGACHAT_CREDENTIALS` | Ключ авторизации GigaChat |

Редактировать `~/gigachat-proxy/docker-compose.yml` для расширенных настроек:

| Переменная | По умолчанию | Описание |
|---|---|---|
| `GIGACHAT_SCOPE` | `GIGACHAT_API_PERS` | Тип доступа (`GIGACHAT_API_PERS` — физлицо, `GIGACHAT_API_CORP` — юрлицо) |
| `GPT2GIGA_MODE` | `DEV` | `DEV` включает `/docs` и эндпоинты логов; `PROD` отключает |
| `GIGACHAT_TIMEOUT` | `60` | Таймаут запроса в секундах |

## Использование с OpenAI SDK

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://127.0.0.1:8090",
    api_key="dummy",  # любое значение
)

response = client.chat.completions.create(
    model="GigaChat-2-Max",
    messages=[{"role": "user", "content": "Привет!"}],
)
print(response.choices[0].message.content)
```

## Использование с Raycast AI

Добавьте в конфиг провайдера Raycast AI:

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

## Доступные модели

| Модель | Контекст |
|---|---|
| GigaChat-2-Max | 131 072 токена |
| GigaChat-2-Pro | 131 072 токена |
| GigaChat-2 | 131 072 токена |
| GigaChat-Max | 128 000 токенов |
| GigaChat-Pro | 32 768 токенов |

## Эндпоинты прокси

| Эндпоинт | Описание |
|---|---|
| `POST /v1/chat/completions` | Генерация ответов (поддерживается стриминг) |
| `GET /v1/models` | Список доступных моделей |
| `POST /v1/embeddings` | Текстовые эмбеддинги |
| `GET /health` | Проверка работоспособности |
| `GET /docs` | Swagger UI (только в DEV-режиме) |

## Управление контейнером

```bash
cd ~/gigachat-proxy

docker compose logs -f      # логи в реальном времени
docker compose down         # остановить
docker compose up -d        # запустить
docker compose restart      # перезапустить
```

## Лицензия

MIT

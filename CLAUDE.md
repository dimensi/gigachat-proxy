# GigaChat Proxy — AI Context

## Что это

Интерактивный установщик и конфигурация для **OpenAI-совместимого прокси GigaChat**.

Прокси транслирует запросы в формате OpenAI API → GigaChat API (Сбер).
Любой инструмент с поддержкой `base_url` (Cursor, Aider, LangChain, OpenAI SDK и т.д.)
работает с GigaChat без изменений в коде.

Под капотом используется [gpt2giga](https://github.com/ai-forever/gpt2giga) — запускается в Docker.

---

## Структура проекта

```
setup.sh           # Интерактивный установщик (главный артефакт)
docker-compose.yml # Docker Compose конфиг для локальной разработки/тестирования
test.py            # Smoke-тест: health, models, chat, streaming
index.html         # Лендинг (Tailwind CDN, тёмная тема, нeon-зелёный)
CNAME              # gigachat.dimensi.dev → GitHub Pages
README.md          # Документация на русском
```

---

## Как работает setup.sh

Скрипт предназначен для запуска через `curl | bash` на macOS и Ubuntu/Debian.

Последовательность:
1. Определяет ОС
2. Проверяет Docker, устанавливает если нет (Homebrew / get.docker.com)
3. Ждёт Docker daemon
4. Запрашивает `GIGACHAT_CREDENTIALS` у пользователя
5. Создаёт `~/gigachat-proxy/` с `.env`, `docker-compose.yml`, `test.py`
6. `docker compose up -d`
7. Ждёт `/health` на порту 8090
8. Запускает `test.py`

Идемпотентен: повторный запуск предложит оставить существующий ключ и пересоздаст контейнер.

---

## Критически важные детали

### curl | bash и stdin

**Проблема:** при `curl url | bash` stdin bash'а — это pipe со скриптом. `read` внутри
скрипта читал бы из pipe (то есть сам скрипт), а не с клавиатуры.

**Решение:** каждый интерактивный `read` имеет явный редирект `</dev/tty`.

```bash
read -r -s -p "Вставьте ключ: " GIGACHAT_CREDENTIALS </dev/tty
```

**Нельзя** использовать `exec </dev/tty` в начале скрипта — bash перестаёт читать
скрипт из pipe и зависает.

### Docker образ

Используется **`gigateam/gpt2giga:latest`** (Docker Hub), а не `ghcr.io/ai-forever/gpt2giga`.
GitHub Container Registry требует аутентификацию даже для публичных образов в некоторых
окружениях — Docker Hub работает без авторизации везде.

### SSL сертификаты GigaChat

`GIGACHAT_VERIFY_SSL_CERTS=False` — GigaChat использует российские CA-сертификаты,
которых нет в стандартном пуле Docker-образа.

### Scope авторизации

По умолчанию `GIGACHAT_SCOPE=GIGACHAT_API_PERS` (физическое лицо).
Для корпоративного доступа: `GIGACHAT_API_CORP` или `GIGACHAT_API_B2B`.

---

## Переменные окружения

| Переменная | Значение | Описание |
|---|---|---|
| `GIGACHAT_CREDENTIALS` | base64 ключ | Ключ авторизации из developers.sber.ru/studio |
| `GIGACHAT_SCOPE` | `GIGACHAT_API_PERS` | Тип доступа |
| `GIGACHAT_VERIFY_SSL_CERTS` | `False` | Отключена из-за российских CA |
| `GIGACHAT_TIMEOUT` | `60` | Таймаут запроса в секундах |
| `GPT2GIGA_HOST` | `0.0.0.0` | Внутри контейнера слушает все интерфейсы |
| `GPT2GIGA_PORT` | `8090` | Порт |
| `GPT2GIGA_MODE` | `DEV` | DEV включает /docs и log-эндпоинты |

---

## Эндпоинты прокси (порт 8090)

| Эндпоинт | Описание |
|---|---|
| `POST /v1/chat/completions` | Chat completions, поддерживает streaming |
| `GET /v1/models` | Список моделей GigaChat |
| `POST /v1/embeddings` | Эмбеддинги |
| `GET /health` | Health check |
| `GET /docs` | Swagger UI (только DEV) |

Авторизация на прокси отключена (`GPT2GIGA_ENABLE_API_KEY_AUTH=False`).
В качестве `api_key` у клиентов — любое значение, например `dummy`.

---

## Команды для работы

```bash
# Запустить прокси
cd ~/gigachat-proxy && docker compose up -d

# Остановить
docker compose down

# Логи в реальном времени
docker compose logs -f

# Проверить API
python3 ~/gigachat-proxy/test.py

# Перезапустить с новым ключом
cd ~/gigachat-proxy && docker compose up -d --force-recreate
```

---

## Деплой лендинга

Лендинг (`index.html`) публикуется автоматически через GitHub Actions (`.github/workflows/deploy.yml`)
при каждом пуше в `main`. Хостинг — GitHub Pages.

- URL: https://gigachat.dimensi.dev
- Репозиторий: https://github.com/dimensi/gigachat-proxy
- CNAME: `gigachat.dimensi.dev` → `dimensi.github.io` (Cloudflare DNS, proxy off)

---

## Известные проблемы и решения

| Проблема | Причина | Решение |
|---|---|---|
| `read` берёт данные из скрипта | `curl \| bash` — stdin это pipe | `</dev/tty` на каждом `read` |
| Скрипт зависает после баннера | `exec </dev/tty` прерывает чтение скрипта | Не использовать `exec`, только per-read |
| `ghcr.io: denied` | GHCR требует auth в некоторых окружениях | Используем `gigateam/gpt2giga` (Docker Hub) |
| SSL ошибки к GigaChat | Российские CA не в стандартном пуле | `GIGACHAT_VERIFY_SSL_CERTS=False` |

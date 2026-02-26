#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
#  GigaChat Proxy — интерактивный установщик
# ─────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "${GREEN}✓${RESET} $*"; }
info() { echo -e "${CYAN}→${RESET} $*"; }
warn() { echo -e "${YELLOW}⚠${RESET} $*"; }
err()  { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }
header() { echo -e "\n${BOLD}${CYAN}$*${RESET}"; }

INSTALL_DIR="$HOME/gigachat-proxy"

# ─── 1. Определяем ОС ───────────────────────
detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)
      if [ -f /etc/debian_version ]; then echo "debian"
      elif [ -f /etc/redhat-release ]; then echo "rhel"
      else err "Неподдерживаемый дистрибутив Linux. Установите Docker вручную и перезапустите скрипт."
      fi ;;
    *) err "Неподдерживаемая ОС: $(uname -s)" ;;
  esac
}

# ─── 2. Установка Docker ─────────────────────
install_docker_macos() {
  if command -v brew &>/dev/null; then
    info "Устанавливаем Docker Desktop через Homebrew..."
    brew install --cask docker
    info "Запускаем Docker Desktop (подождите 30–60 секунд)..."
    open -a Docker
  else
    warn "Homebrew не найден."
    echo "Установите Docker Desktop вручную: https://www.docker.com/products/docker-desktop/"
    echo "После установки перезапустите этот скрипт."
    exit 1
  fi
}

install_docker_linux() {
  info "Устанавливаем Docker Engine (официальный скрипт)..."
  curl -fsSL https://get.docker.com | sudo sh
  sudo systemctl enable --now docker
  # Добавляем пользователя в группу docker (без sudo для следующих команд)
  sudo usermod -aG docker "$USER"
  warn "Вы добавлены в группу 'docker'. Для применения без sudo нужно перелогиниться."
  warn "Сейчас продолжаем с sudo..."
  DOCKER_CMD="sudo docker"
  COMPOSE_CMD="sudo docker compose"
}

ensure_docker() {
  header "Проверка Docker"
  if ! command -v docker &>/dev/null; then
    warn "Docker не найден. Устанавливаем..."
    OS=$(detect_os)
    case "$OS" in
      macos)   install_docker_macos ;;
      debian)  install_docker_linux ;;
      rhel)    install_docker_linux ;;
    esac
  else
    ok "Docker установлен: $(docker --version 2>/dev/null | head -1)"
  fi

  # Ждём, пока Docker daemon запустится
  info "Ожидаем запуска Docker daemon..."
  local i=0
  until ${DOCKER_CMD:-docker} info &>/dev/null 2>&1; do
    i=$((i+1))
    if [ $i -ge 30 ]; then
      err "Docker daemon не запустился за 60 секунд. Запустите Docker Desktop вручную и повторите."
    fi
    printf "."
    sleep 2
  done
  echo ""
  ok "Docker daemon запущен"
}

# ─── 3. Ключ авторизации ─────────────────────
ask_credentials() {
  header "Ключ авторизации GigaChat"
  echo "Получить ключ: https://developers.sber.ru/studio/"
  echo ""

  # Если ключ уже есть в .env — предложить оставить
  if [ -f "$INSTALL_DIR/.env" ] && grep -q "^GIGACHAT_CREDENTIALS=" "$INSTALL_DIR/.env"; then
    local existing
    existing=$(grep "^GIGACHAT_CREDENTIALS=" "$INSTALL_DIR/.env" | cut -d= -f2- | tr -d '"')
    if [ -n "$existing" ] && [ "$existing" != "ВСТАВЬТЕ_ВАШ_КЛЮЧ_СЮДА" ]; then
      echo -e "Найден существующий ключ: ${CYAN}${existing:0:12}...${RESET}"
      read -r -p "Оставить текущий ключ? [Y/n]: " keep </dev/tty
      if [[ "${keep:-Y}" =~ ^[Yy]$ ]]; then
        GIGACHAT_CREDENTIALS="$existing"
        return
      fi
    fi
  fi

  while true; do
    read -r -s -p "Вставьте ключ авторизации (ввод скрыт): " GIGACHAT_CREDENTIALS </dev/tty
    echo ""
    if [ -z "$GIGACHAT_CREDENTIALS" ]; then
      warn "Ключ не может быть пустым. Попробуйте ещё раз."
    else
      ok "Ключ принят (${#GIGACHAT_CREDENTIALS} символов)"
      break
    fi
  done
}

# ─── 4. Создаём файлы ────────────────────────
write_files() {
  header "Создание файлов в $INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"

  # .env
  cat > "$INSTALL_DIR/.env" <<EOF
# Ключ авторизации GigaChat (base64-encoded client_id:client_secret)
GIGACHAT_CREDENTIALS="${GIGACHAT_CREDENTIALS}"
EOF
  ok ".env"

  # docker-compose.yml
  cat > "$INSTALL_DIR/docker-compose.yml" <<'EOF'
services:
  gpt2giga:
    image: ghcr.io/ai-forever/gpt2giga:latest
    ports:
      - "127.0.0.1:8090:8090"
    env_file:
      - .env
    environment:
      GPT2GIGA_HOST: "0.0.0.0"
      GPT2GIGA_PORT: "8090"
      GPT2GIGA_MODE: "DEV"
      GPT2GIGA_LOG_LEVEL: "INFO"
      GIGACHAT_SCOPE: "GIGACHAT_API_PERS"
      GIGACHAT_VERIFY_SSL_CERTS: "False"
      GIGACHAT_TIMEOUT: "60"
    restart: unless-stopped
EOF
  ok "docker-compose.yml"

  # test.py
  cat > "$INSTALL_DIR/test.py" <<'PYEOF'
#!/usr/bin/env python3
import json, sys, urllib.request, urllib.error

BASE_URL = "http://127.0.0.1:8090"
HEADERS  = {"Content-Type": "application/json", "Authorization": "Bearer dummy"}
PASS = "\033[92mPASS\033[0m"; FAIL = "\033[91mFAIL\033[0m"

def request(method, path, body=None):
    data = json.dumps(body).encode() if body else None
    req  = urllib.request.Request(BASE_URL + path, data=data, headers=HEADERS, method=method)
    resp = urllib.request.urlopen(req, timeout=60)
    return resp.status, json.loads(resp.read())

def test_health():
    print("1. GET /health ... ", end="", flush=True)
    try:
        req  = urllib.request.Request(BASE_URL + "/health", headers=HEADERS)
        resp = urllib.request.urlopen(req, timeout=10)
        assert resp.status == 200
        print(PASS, f"({resp.read().decode().strip()!r})")
        return True
    except Exception as e:
        print(FAIL, f"({e})"); return False

def test_models():
    print("2. GET /v1/models ... ", end="", flush=True)
    try:
        _, body  = request("GET", "/v1/models")
        models   = [m["id"] for m in body.get("data", [])]
        print(PASS, f"(модели: {', '.join(models[:3])}{'...' if len(models) > 3 else ''})")
        return True
    except Exception as e:
        print(FAIL, f"({e})"); return False

def test_chat():
    print("3. POST /v1/chat/completions ... ", end="", flush=True)
    try:
        _, body = request("POST", "/v1/chat/completions", {
            "model": "GigaChat", "messages": [{"role": "user", "content": "Скажи только: OK"}], "max_tokens": 10,
        })
        answer = body["choices"][0]["message"]["content"]
        print(PASS, f"(ответ: {answer!r})"); return True
    except Exception as e:
        print(FAIL, f"({e})"); return False

def test_stream():
    print("4. POST /v1/chat/completions (stream) ... ", end="", flush=True)
    try:
        body = json.dumps({"model": "GigaChat", "messages": [{"role": "user", "content": "Привет"}],
                           "max_tokens": 20, "stream": True}).encode()
        req  = urllib.request.Request(BASE_URL + "/v1/chat/completions", data=body, headers=HEADERS, method="POST")
        resp = urllib.request.urlopen(req, timeout=60)
        chunks = sum(1 for line in resp if b"data:" in line and b"[DONE]" not in line)
        assert chunks > 0
        print(PASS, f"({chunks} чанков)"); return True
    except Exception as e:
        print(FAIL, f"({e})"); return False

if __name__ == "__main__":
    print(f"Тестируем прокси: {BASE_URL}\n")
    results = [test_health(), test_models(), test_chat(), test_stream()]
    passed = sum(results)
    print(f"\nРезультат: {passed}/{len(results)} тестов прошло")
    sys.exit(0 if passed == len(results) else 1)
PYEOF
  ok "test.py"
}

# ─── 5. Запуск контейнера ────────────────────
start_proxy() {
  header "Запуск прокси"
  cd "$INSTALL_DIR"

  local dc="${COMPOSE_CMD:-docker compose}"

  # Если контейнер уже запущен — рестартуем (чтобы подхватить новый .env)
  if $dc ps --services --filter "status=running" 2>/dev/null | grep -q gpt2giga; then
    info "Контейнер уже запущен — перезапускаем для применения нового ключа..."
    $dc up -d --force-recreate
  else
    $dc up -d
  fi

  # Ждём, пока сервер ответит на /health
  info "Ожидаем готовности прокси (порт 8090)..."
  local i=0
  until curl -sf http://127.0.0.1:8090/health &>/dev/null; do
    i=$((i+1))
    [ $i -ge 30 ] && err "Прокси не ответил за 60 секунд. Логи: cd $INSTALL_DIR && docker compose logs"
    printf "."
    sleep 2
  done
  echo ""
  ok "Прокси запущен на http://127.0.0.1:8090"
}

# ─── 6. Тест ─────────────────────────────────
run_tests() {
  header "Тестирование API"
  if command -v python3 &>/dev/null; then
    python3 "$INSTALL_DIR/test.py"
  else
    warn "python3 не найден — пропускаем тест. Установите Python 3 для проверки."
  fi
}

# ─── Итог ─────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}════════════════════════════════════════${RESET}"
  echo -e "${BOLD}  GigaChat прокси успешно запущен!${RESET}"
  echo -e "${BOLD}${GREEN}════════════════════════════════════════${RESET}"
  echo ""
  echo -e "  ${BOLD}URL:${RESET}      http://127.0.0.1:8090"
  echo -e "  ${BOLD}API key:${RESET}  dummy (любое значение)"
  echo -e "  ${BOLD}Логи:${RESET}     cd ~/gigachat-proxy && docker compose logs -f"
  echo -e "  ${BOLD}Стоп:${RESET}     cd ~/gigachat-proxy && docker compose down"
  echo ""
  echo -e "  ${BOLD}Raycast / OpenAI SDK:${RESET}"
  echo -e "    base_url = http://127.0.0.1:8090"
  echo -e "    api_key  = dummy"
  echo ""
}

# ─── MAIN ─────────────────────────────────────

# Переподключаем stdin к терминалу — иначе read читает из pipe при curl | bash
if [ -t 0 ]; then
  : # stdin уже терминал (запуск из файла)
elif [ -e /dev/tty ]; then
  exec </dev/tty
else
  err "Запустите скрипт так: bash <(curl -fsSL https://gigachat.dimensi.dev/setup.sh)"
fi

DOCKER_CMD="docker"
COMPOSE_CMD="docker compose"

echo -e "${BOLD}${CYAN}"
echo "  ██████╗ ██╗ ██████╗  █████╗  ██████╗██╗  ██╗ █████╗ ████████╗"
echo "  ██╔════╝██║██╔════╝ ██╔══██╗██╔════╝██║  ██║██╔══██╗╚══██╔══╝"
echo "  ██║  ███╗██║██║  ███╗███████║██║     ███████║███████║   ██║   "
echo "  ██║   ██║██║██║   ██║██╔══██║██║     ██╔══██║██╔══██║   ██║   "
echo "  ╚██████╔╝██║╚██████╔╝██║  ██║╚██████╗██║  ██║██║  ██║   ██║   "
echo "   ╚═════╝ ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   "
echo -e "${RESET}"
echo -e "  ${BOLD}OpenAI-совместимый прокси для GigaChat${RESET}"
echo ""

ensure_docker
ask_credentials
write_files
start_proxy
run_tests
print_summary

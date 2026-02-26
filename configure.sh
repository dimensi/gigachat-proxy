#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
#  GigaChat Proxy — настройка инструментов
# ─────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()     { echo -e "${GREEN}✓${RESET} $*"; }
info()   { echo -e "${CYAN}→${RESET} $*"; }
warn()   { echo -e "${YELLOW}⚠${RESET} $*"; }
err()    { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }
header() { echo -e "\n${BOLD}${CYAN}$*${RESET}"; }
divider(){ echo -e "${CYAN}──────────────────────────────────────────────${RESET}"; }

PROXY_URL="http://127.0.0.1:8090"

# ─── Проверка прокси ───────────────────────
check_proxy() {
  if ! curl -sf "${PROXY_URL}/health" &>/dev/null; then
    err "Прокси не запущен на ${PROXY_URL}. Сначала выполните:
  curl -fsSL https://gigachat.dimensi.dev/setup.sh | bash"
  fi
  ok "Прокси доступен: ${PROXY_URL}"
}

# ─── Получение моделей ─────────────────────
# Возвращает строку с ID моделей через пробел
fetch_models() {
  local models=""
  if command -v python3 &>/dev/null; then
    models=$(python3 -c "
import urllib.request, json, sys
try:
    r = urllib.request.urlopen('${PROXY_URL}/v1/models', timeout=5)
    data = json.loads(r.read())
    print(' '.join(m['id'] for m in data.get('data', [])))
except Exception:
    sys.exit(1)
" 2>/dev/null) || true
  fi
  if [ -z "$models" ]; then
    # fallback: grep из curl-ответа
    models=$(curl -sf "${PROXY_URL}/v1/models" \
      | grep -o '"id":"[^"]*"' \
      | cut -d'"' -f4 \
      | tr '\n' ' ' \
      | sed 's/ $//' ) || true
  fi
  if [ -z "$models" ]; then
    # последний fallback: hardcode
    models="GigaChat-2-Max GigaChat-2-Pro GigaChat-2 GigaChat-Max GigaChat-Pro"
    warn "Не удалось получить список моделей — используется список по умолчанию"
  fi
  echo "$models"
}

# ─── Хелперы для моделей ───────────────────
get_model_name() {
  case "$1" in
    GigaChat-2-Max) echo "GigaChat 2 Max" ;;
    GigaChat-2-Pro) echo "GigaChat 2 Pro" ;;
    GigaChat-2)     echo "GigaChat 2" ;;
    GigaChat-Max)   echo "GigaChat Max" ;;
    GigaChat-Pro)   echo "GigaChat Pro" ;;
    *)              echo "$1" ;;
  esac
}

get_context_window() {
  case "$1" in
    GigaChat-2-Max|GigaChat-2-Pro|GigaChat-2) echo "131072" ;;
    GigaChat-Max)                              echo "128000" ;;
    GigaChat-Pro)                              echo "32768" ;;
    *)                                         echo "32768" ;;
  esac
}

# ─── Cursor ────────────────────────────────
show_cursor() {
  local settings_file
  if [ "$(uname -s)" = "Darwin" ]; then
    settings_file="$HOME/Library/Application Support/Cursor/User/settings.json"
  else
    settings_file="$HOME/.config/Cursor/User/settings.json"
  fi

  header "Cursor"
  echo -e "  Откройте Settings > AI в Cursor или отредактируйте:"
  echo -e "  ${BOLD}${settings_file}${RESET}"
  echo ""
  divider
  cat <<'EOF'
  "openai.apiKey": "dummy",
  "openai.baseUrl": "http://127.0.0.1:8090"
EOF
  divider
}

# ─── Raycast AI ────────────────────────────
show_raycast() {
  local models="$1"
  local file="$HOME/Library/Application Support/com.raycast.macos/customAIProviders.yaml"

  header "Raycast AI"
  echo -e "  Файл: ${BOLD}${file}${RESET}"
  echo ""
  divider
  echo "- id: gigachat"
  echo "  name: GigaChat"
  echo "  base_url: http://127.0.0.1:8090"
  echo "  api_keys:"
  echo "    gigachat: dummy"
  echo "  models:"
  for model_id in $models; do
    local name ctx
    name=$(get_model_name "$model_id")
    ctx=$(get_context_window "$model_id")
    echo "    - id: ${model_id}"
    echo "      name: ${name}"
    echo "      provider: gigachat"
    echo "      context: ${ctx}"
    echo "      abilities:"
    echo "        temperature:"
    echo "          supported: true"
    echo "        vision:"
    echo "          supported: true"
    echo "        system_message:"
    echo "          supported: true"
    echo "        tools:"
    echo "          supported: true"
    echo "        reasoning_effort:"
    echo "          supported: false"
  done
  divider
}

# ─── Zed ───────────────────────────────────
show_zed() {
  local models="$1"
  local file="$HOME/.config/zed/settings.json"

  header "Zed"
  echo -e "  Файл: ${BOLD}${file}${RESET}"
  echo ""
  divider
  echo '"language_models": {'
  echo '  "openai": {'
  echo '    "api_url": "http://127.0.0.1:8090",'
  echo '    "available_models": ['
  local first=true
  for model_id in $models; do
    local name ctx
    name=$(get_model_name "$model_id")
    ctx=$(get_context_window "$model_id")
    [ "$first" = true ] || echo "      ,"
    first=false
    echo "      {"
    echo "        \"name\": \"${model_id}\","
    echo "        \"display_name\": \"${name}\","
    echo "        \"max_tokens\": ${ctx}"
    echo "      }"
  done
  echo '    ]'
  echo '  }'
  echo '}'
  divider
}

# ─── Меню ──────────────────────────────────
show_menu() {
  echo ""
  echo -e "${BOLD}Выберите инструменты для настройки:${RESET}"
  echo ""
  echo "  [1] Cursor"
  echo "  [2] Raycast AI  (только macOS)"
  echo "  [3] Zed"
  echo "  [4] Aider"
  echo "  [5] Claude Code"
  echo "  [6] OpenClaw"
  echo ""
  echo -e "  [a] Все инструменты"
  echo ""
  printf "Введите номера через пробел (например: 1 3 5) или 'a': "
  read -r CHOICE </dev/tty
}

dispatch() {
  local choice="$1"
  local models="$2"

  if [ "$choice" = "a" ]; then
    choice="1 2 3 4 5 6"
  fi

  for num in $choice; do
    case "$num" in
      1) show_cursor ;;
      2) show_raycast "$models" ;;
      3) show_zed "$models" ;;
      4) show_aider ;;
      5) show_claude_code ;;
      6) show_openclaw "$models" ;;
      *) warn "Неизвестный номер: $num — пропускаем" ;;
    esac
  done
}

# ─── Stubs (заменяются в Task 4) ────────────
show_aider()      { echo "aider"; }
show_claude_code(){ echo "claude"; }
show_openclaw()   { echo "openclaw"; }

# ─── MAIN ──────────────────────────────────
echo -e "${BOLD}${CYAN}"
echo "  GigaChat Proxy — настройка инструментов"
echo -e "${RESET}"

check_proxy
MODELS=$(fetch_models)
ok "Модели: ${MODELS}"

show_menu
dispatch "$CHOICE" "$MODELS"

echo ""
ok "Готово!"

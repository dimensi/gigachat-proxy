#!/usr/bin/env python3
"""
Тест gpt2giga прокси: проверяет health, models, chat completions и streaming.
Запуск: python test.py
"""

import json
import sys
import urllib.request
import urllib.error

BASE_URL = "http://127.0.0.1:8090"
# Прокси не требует API-ключ (GPT2GIGA_ENABLE_API_KEY_AUTH=False по умолчанию)
HEADERS = {"Content-Type": "application/json", "Authorization": "Bearer dummy"}

PASS = "\033[92mPASS\033[0m"
FAIL = "\033[91mFAIL\033[0m"


def request(method, path, body=None):
    url = BASE_URL + path
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, headers=HEADERS, method=method)
    resp = urllib.request.urlopen(req, timeout=60)
    return resp.status, json.loads(resp.read())


def test_health():
    print("1. GET /health ... ", end="", flush=True)
    try:
        url = BASE_URL + "/health"
        req = urllib.request.Request(url, headers=HEADERS, method="GET")
        resp = urllib.request.urlopen(req, timeout=10)
        assert resp.status == 200, f"status={resp.status}"
        body = resp.read().decode()
        print(PASS, f"({body.strip()!r})")
        return True
    except Exception as e:
        print(FAIL, f"({e})")
        return False


def test_models():
    print("2. GET /v1/models ... ", end="", flush=True)
    try:
        status, body = request("GET", "/v1/models")
        assert status == 200
        models = [m["id"] for m in body.get("data", [])]
        print(PASS, f"(модели: {', '.join(models[:3])}{'...' if len(models) > 3 else ''})")
        return True
    except Exception as e:
        print(FAIL, f"({e})")
        return False


def test_chat():
    print("3. POST /v1/chat/completions ... ", end="", flush=True)
    try:
        status, body = request("POST", "/v1/chat/completions", {
            "model": "GigaChat",
            "messages": [{"role": "user", "content": "Скажи только: OK"}],
            "max_tokens": 10,
        })
        assert status == 200
        answer = body["choices"][0]["message"]["content"]
        print(PASS, f"(ответ: {answer!r})")
        return True
    except Exception as e:
        print(FAIL, f"({e})")
        return False


def test_stream():
    print("4. POST /v1/chat/completions (stream) ... ", end="", flush=True)
    try:
        url = BASE_URL + "/v1/chat/completions"
        body = json.dumps({
            "model": "GigaChat",
            "messages": [{"role": "user", "content": "Привет"}],
            "max_tokens": 20,
            "stream": True,
        }).encode()
        req = urllib.request.Request(url, data=body, headers=HEADERS, method="POST")
        resp = urllib.request.urlopen(req, timeout=60)
        chunks = 0
        for line in resp:
            line = line.decode().strip()
            if line.startswith("data:") and "[DONE]" not in line:
                chunks += 1
        assert chunks > 0, "нет чанков"
        print(PASS, f"({chunks} чанков)")
        return True
    except Exception as e:
        print(FAIL, f"({e})")
        return False


if __name__ == "__main__":
    print(f"Тестируем прокси: {BASE_URL}\n")
    results = [test_health(), test_models(), test_chat(), test_stream()]
    print()
    passed = sum(results)
    total = len(results)
    print(f"Результат: {passed}/{total} тестов прошло")
    sys.exit(0 if passed == total else 1)

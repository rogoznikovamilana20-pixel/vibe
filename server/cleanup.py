import json
import urllib.request

BASE = "http://127.0.0.1:8090/api"

def call(method, path, data=None, token=None):
    req = urllib.request.Request(BASE + path, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    body = None if data is None else json.dumps(data).encode("utf-8")
    try:
        with urllib.request.urlopen(req, data=body) as resp:
            b = resp.read().decode("utf-8")
            return json.loads(b) if b else None
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, e.read().decode("utf-8"))
        raise

r = call("POST", "/collections/_superusers/auth-with-password",
         {"identity": "admin@vibe.local", "password": "VibeAdmin2026!"})
tok = r["token"]

# удаляем все существующие чаты и сообщения (пересоздадим чистый сид)
msgs = call("GET", "/collections/messages/records?perPage=500", token=tok)["items"]
for m in msgs:
    call("DELETE", "/collections/messages/records/" + m["id"], token=tok)
print("messages deleted:", len(msgs))

chats = call("GET", "/collections/chats/records?perPage=100", token=tok)["items"]
for c in chats:
    call("DELETE", "/collections/chats/records/" + c["id"], token=tok)
print("chats deleted:", len(chats))

# и дубли profiles-сидов (профили контактов уникальны по username, оставляем)
print("done")
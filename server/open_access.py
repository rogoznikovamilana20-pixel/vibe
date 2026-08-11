import json
import urllib.request

BASE = "http://127.0.0.1:8090/api"

def call(method, path, data=None, token=None):
    req = urllib.request.Request(BASE + path, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    body = None if data is None else json.dumps(data).encode("utf-8")
    with urllib.request.urlopen(req, data=body) as resp:
        return json.loads(resp.read().decode("utf-8"))

r = call("POST", "/collections/_superusers/auth-with-password",
         {"identity": "admin@vibe.local", "password": "VibeAdmin2026!"})
tok = r["token"]

# Открыть доступ: пустые строки = "no auth required"
for col in ["profiles", "chats", "messages"]:
    coll = call("GET", f"/collections/{col}", token=tok)
    coll["listRule"] = ""
    coll["viewRule"] = ""
    coll["createRule"] = ""
    coll["updateRule"] = ""
    coll["deleteRule"] = ""
    call("PATCH", f"/collections/{col}", coll, token=tok)
    print("opened", col)
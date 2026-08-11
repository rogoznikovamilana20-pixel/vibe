import json
import urllib.parse
import urllib.request
import random

BASE = "http://127.0.0.1:8090/api"

def call(method, path, data=None, token=None):
    req = urllib.request.Request(BASE + urllib.parse.quote(path, safe="/?='_"), method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    body = None if data is None else json.dumps(data).encode("utf-8")
    try:
        with urllib.request.urlopen(req, data=body) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, e.read().decode("utf-8"))
        raise

def gen_uid():
    return random.randint(10000000, 99999999)

# auth superuser
r = call("POST", "/collections/_superusers/auth-with-password", {
    "identity": "admin@vibe.local", "password": "VibeAdmin2026!",
})
tok = r["token"]

# me
me_q = call("GET", "/collections/profiles/records?filter=username='andrey'", token=tok)
if me_q["items"]:
    me = me_q["items"][0]
    if not me.get("uid"):
        me = call("PATCH", f"/collections/profiles/records/{me['id']}", {"uid": gen_uid()}, token=tok)
else:
    me = call("POST", "/collections/profiles/records",
              {"username": "andrey", "displayName": "Андрей", "online": True, "uid": gen_uid()},
              token=tok)
print("ME", me["id"], "UID", me.get("uid"))

# Специальные чаты
special_names = [
    ("Избранное", "pm", "Сохраняй здесь важные мысли и файлы 🔖"),
    ("Служба поддержки Vibe", "pm", "Привет! Мы поможем с любым вопросом по Vibe ⚡"),
]

for display, kind, welcome in special_names:
    username = "".join(ch for ch in display.lower() if ch.isalpha()) + "_sys"
    q = call("GET", f"/collections/profiles/records?filter=username='{username}'", token=tok)
    if q["items"]:
        pid = q["items"][0]["id"]
    else:
        pid = call("POST", "/collections/profiles/records",
                   {"username": username, "displayName": display, "online": True, "uid": gen_uid()},
                   token=tok)["id"]

    # Ищем существующий чат
    c_q = call("GET", f"/collections/chats/records?filter=title='{display}'", token=tok)
    if c_q["items"]:
        chat_id = c_q["items"][0]["id"]
    else:
        chat = call("POST", "/collections/chats/records",
                    {"title": display, "kind": kind, "members": [me["id"], pid] if display != "Избранное" else [me["id"]]},
                    token=tok)
        chat_id = chat["id"]
        # Приветственное сообщение
        call("POST", "/collections/messages/records",
             {"chat": chat_id, "sender": pid if display != "Избранное" else me["id"], "text": welcome}, token=tok)
    print("SPECIAL CHAT", display, chat_id)

names_kinds = [
    ("Aurion", "pm"), ("Алиса Ким", "pm"), ("Команда Vibe", "group"),
    ("Марк Осипов", "pm"), ("Студия Вайбика", "channel"), ("Криптоновости", "channel"),
    ("Daria Store", "biz"), ("Семья", "group"), ("Кодер Хаус", "group"),
    ("Ника Л.", "pm"), ("Дима Б.", "pm"), ("Соня И.", "pm"),
    ("Ретро-чай", "biz"), ("Голосовой Еж", "channel"), ("Тусовка DJ Nord", "group"),
]

for i, (display, kind) in enumerate(names_kinds):
    username = "".join(ch for ch in display.lower() if ch.isalpha()) + "_seed"
    q = call("GET", f"/collections/profiles/records?filter=username='{username}'", token=tok)
    if q["items"]:
        pid = q["items"][0]["id"]
        # Убедимся что есть UID
        if not q["items"][0].get("uid"):
            call("PATCH", f"/collections/profiles/records/{pid}", {"uid": gen_uid()}, token=tok)
    else:
        pid = call("POST", "/collections/profiles/records",
                   {"username": username, "displayName": display, "online": (i % 3 == 0), "uid": gen_uid()},
                   token=tok)["id"]

    # Чат
    c_q = call("GET", f"/collections/chats/records?filter=title='{display}'", token=tok)
    if not c_q["items"]:
        chat = call("POST", "/collections/chats/records",
                    {"title": display, "kind": kind, "members": [me["id"], pid]},
                    token=tok)
        chat_id = chat["id"]
        lasts = [
            "Разобрал твой вопрос — вот решение 🧠",
            "Смотри, какой мем прислали 😂", "Напоминалка: стендап в 10:00",
            "Отправил макет, проверь почту", "Новый пак «Ракета» уже в магазине 🚀",
            "Квантовые компьютеры подбираются к RSA", "Заказ #142 готов к выдаче 📦",
            "Забери хлеб по дороге домой", "Деплой прошёл за 3 минуты ⚡",
            "Ахах, гениально 🤣", "Го кататься в субботу?", "Прислала те те самые рефы",
            "Сегодня доставим со скидкой 20%", "Волна записалась, конвертирую в текст…",
            "Сет в клубе — 23:00, билет за тобой",
        ][i % 15]
        call("POST", "/collections/messages/records",
             {"chat": chat_id, "sender": pid, "text": lasts}, token=tok)
        print("CHAT", display, chat_id)

print("SEED_DONE me=", me["id"])

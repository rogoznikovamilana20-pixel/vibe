// Поместите этот файл в папку pb_hooks вашего PocketBase
// Этот хук отправляет уведомления через Firebase при создании нового сообщения

onRecordAfterCreateRequest((e) => {
    const message = e.record;
    const senderId = message.getString("sender");
    const chat = $app.dao().findRecordById("chats", message.getString("chat"));
    const members = chat.getStringSlice("members");

    // Находим отправителя, чтобы знать его имя
    const sender = $app.dao().findRecordById("profiles", senderId);
    const senderName = sender.getString("displayName") || sender.getString("username");

    members.forEach((memberId) => {
        if (memberId === senderId) return; // Не отправляем самому себе

        // Находим получателя и его токен
        const recipient = $app.dao().findRecordById("profiles", memberId);
        const token = recipient.getString("fcmToken");

        if (token) {
            // Отправка через Firebase Messaging API v1
            // Примечание: Для работы в облаке PocketHost может потребоваться дополнительная настройка OAuth2.
            // Ниже приведен каркас запроса.

            try {
                $http.send({
                    url: "https://fcm.googleapis.com/fcm/send", // Legacy API для простоты прототипа
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json",
                        "Authorization": "key=ВАШ_LEGACY_SERVER_KEY_ИЗ_FIREBASE" // См. примечание ниже
                    },
                    body: JSON.stringify({
                        to: token,
                        notification: {
                            title: senderName,
                            body: message.getString("text") || "Голосовое сообщение или фото",
                            sound: "default"
                        },
                        data: {
                            chatId: chat.id
                        }
                    })
                });
            } catch (err) {
                console.log("Push send error: " + err);
            }
        }
    });
}, "messages");

// ВАЖНО: Google переходит на FCM v1 API.
// Чтобы этот скрипт заработал мгновенно, включите "Cloud Messaging API (Legacy)"
// в Firebase Console -> Project Settings -> Cloud Messaging.
// Скопируйте "Server Key" и вставьте его выше в поле Authorization.

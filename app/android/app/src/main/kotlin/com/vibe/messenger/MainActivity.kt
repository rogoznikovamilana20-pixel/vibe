package com.vibe.messenger

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)

            nm.createNotificationChannel(
                NotificationChannel(
                    "messages",
                    "Сообщения",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Новые сообщения в чатах Vibe"
                    enableVibration(true)
                },
            )

            nm.createNotificationChannel(
                NotificationChannel(
                    "stories",
                    "Сториз",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply {
                    description = "Новые стори от контактов"
                    setSound(null, null)
                },
            )
        }
    }
}
package com.lamsa.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    /**
     * The backend sets `channel_id` on every push: `orders` (high importance:
     * order updates) or `marketing` (everything else). Android 8+ needs the
     * channels to exist before a push uses them; creating them again is a no-op.
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val orders = NotificationChannel(
            "orders",
            getString(R.string.channel_orders_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply { description = getString(R.string.channel_orders_description) }
        val marketing = NotificationChannel(
            "marketing",
            getString(R.string.channel_marketing_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply { description = getString(R.string.channel_marketing_description) }
        manager.createNotificationChannels(listOf(orders, marketing))
    }
}

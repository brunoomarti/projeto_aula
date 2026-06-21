package com.tasker.project

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

class MagicTaskWidgetActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val text = extractTaskText(intent)?.trim().orEmpty()
        Log.d(TAG, "Recebido texto (${text.length} chars)")

        if (text.isEmpty()) {
            Log.w(TAG, "Texto vazio")
            return
        }

        context.getSharedPreferences(HOME_WIDGET_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(PENDING_TASK_TEXT_KEY, text)
            .apply()

        try {
            HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("taskerWidget://createTask"),
            ).send()
        } catch (e: Exception) {
            Log.e(TAG, "Falha ao enviar background intent", e)
        }
    }

    private fun extractTaskText(intent: Intent): String? {
        intent.extras?.let { extras ->
            for (key in extras.keySet()) {
                when (val value = extras.get(key)) {
                    is CharSequence -> if (value.isNotBlank()) return value.toString()
                    is String -> if (value.isNotBlank()) return value
                }
            }
        }
        return null
    }

    companion object {
        private const val TAG = "MagicTaskWidgetAction"
        private const val HOME_WIDGET_PREFS = "HomeWidgetPreferences"
        private const val PENDING_TASK_TEXT_KEY = "pending_task_text"
    }
}

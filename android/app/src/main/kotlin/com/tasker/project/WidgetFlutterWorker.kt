package com.tasker.project

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

/// Motor Flutter sem UI — evita overlay em tela cheia que trava a home (Samsung).
object WidgetFlutterWorker {

    private const val TAG = "WidgetFlutterWorker"
    private const val CHANNEL = "com.tasker.project/widget_bridge"
    private const val TIMEOUT_MS = 45_000L

    @Volatile
    private var engine: FlutterEngine? = null

    @Volatile
    private var pendingText: String = ""

    private val handler = Handler(Looper.getMainLooper())
    private var timeoutRunnable: Runnable? = null

    fun processPendingTask(context: Context, text: String) {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) {
            Log.w(TAG, "Texto vazio — ignorando")
            return
        }

        handler.post {
            if (engine != null) {
                Log.w(TAG, "Engine preso — reiniciando")
                destroyEngine()
            }

            pendingText = trimmed
            val appContext = context.applicationContext

            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(appContext)
                loader.ensureInitializationComplete(appContext, null)

                val flutterEngine = FlutterEngine(appContext)
                engine = flutterEngine

                GeneratedPluginRegistrant.registerWith(flutterEngine)

                MethodChannel(
                    flutterEngine.dartExecutor.binaryMessenger,
                    CHANNEL,
                ).setMethodCallHandler { call, result ->
                    when (call.method) {
                        "consumePendingText" -> {
                            val value = pendingText
                            pendingText = ""
                            Log.d(TAG, "Entregando texto ao Dart (${value.length} chars)")
                            result.success(value)
                        }
                        "finish" -> {
                            Log.d(TAG, "Tarefa processada — destruindo engine")
                            cancelTimeout()
                            destroyEngine()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }

                scheduleTimeout()

                Log.d(TAG, "Iniciando entry point headless")
                flutterEngine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(
                        loader.findAppBundlePath(),
                        "widgetTaskEntryPoint",
                    ),
                )
            } catch (e: Exception) {
                Log.e(TAG, "Falha ao processar tarefa do widget", e)
                cancelTimeout()
                destroyEngine()
            }
        }
    }

    private fun scheduleTimeout() {
        cancelTimeout()
        timeoutRunnable = Runnable {
            Log.e(TAG, "Timeout — destruindo engine preso")
            destroyEngine()
        }
        handler.postDelayed(timeoutRunnable!!, TIMEOUT_MS)
    }

    private fun cancelTimeout() {
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        timeoutRunnable = null
    }

    private fun destroyEngine() {
        cancelTimeout()
        engine?.destroy()
        engine = null
        pendingText = ""
    }
}

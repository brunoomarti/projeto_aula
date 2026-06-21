package com.tasker.project

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Shader
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetProvider

class MagicTaskWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val status = widgetData.getString(STATUS_KEY, "") ?: ""

        appWidgetIds.forEach { widgetId ->
            try {
                when (status) {
                    STATUS_SUCCESS, STATUS_ERROR -> {
                        // Consome o status para a animação não reiniciar a cada refresh.
                        if (!animatingIds.contains(widgetId)) {
                            widgetData.edit().putString(STATUS_KEY, "").apply()
                            animateResult(
                                context,
                                appWidgetManager,
                                widgetId,
                                success = status == STATUS_SUCCESS,
                            )
                        }
                    }
                    STATUS_LOADING -> {
                        if (!animatingIds.contains(widgetId)) {
                            appWidgetManager.updateAppWidget(
                                widgetId,
                                rowViews(context, appWidgetManager, widgetId, loading = true, alpha = 1f),
                            )
                        }
                    }
                    else -> {
                        if (!animatingIds.contains(widgetId)) {
                            appWidgetManager.updateAppWidget(
                                widgetId,
                                rowViews(context, appWidgetManager, widgetId, loading = false, alpha = 1f),
                            )
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Falha ao atualizar widget $widgetId", e)
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Construção dos estados visuais
    // ---------------------------------------------------------------------------

    private fun openInputIntent(context: Context, widgetId: Int): PendingIntent {
        return PendingIntent.getActivity(
            context,
            widgetId,
            Intent(context, MagicTaskWidgetInputActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
    }

    /// Estado padrão: ícone + botão (ou spinner de loading).
    private fun rowViews(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        loading: Boolean,
        alpha: Float,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.magic_task_widget)

        views.setViewVisibility(R.id.widget_main_row, View.VISIBLE)
        views.setViewVisibility(R.id.widget_result, View.GONE)
        views.setViewVisibility(
            R.id.widget_create_button,
            if (loading) View.GONE else View.VISIBLE,
        )
        views.setViewVisibility(
            R.id.widget_loading,
            if (loading) View.VISIBLE else View.GONE,
        )

        views.setAlphaCompat(R.id.widget_main_row, alpha)
        applyWidgetIcon(context, appWidgetManager, widgetId, views)

        val intent = openInputIntent(context, widgetId)
        views.setOnClickPendingIntent(R.id.widget_create_button, intent)
        views.setOnClickPendingIntent(R.id.widget_app_icon, intent)
        views.setOnClickPendingIntent(R.id.widget_root, intent)

        return views
    }

    /// Ícone circular (1:1) gerado em runtime — evita o squircle do adaptive icon.
    private fun applyWidgetIcon(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        views: RemoteViews,
    ) {
        val options = appWidgetManager.getAppWidgetOptions(widgetId)
        val heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 40)
        val iconSizeDp = (heightDp - WIDGET_PADDING_DP * 2).coerceAtLeast(28)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setViewLayoutWidth(R.id.widget_app_icon, iconSizeDp.toFloat(), TypedValue.COMPLEX_UNIT_DIP)
            views.setViewLayoutHeight(R.id.widget_app_icon, iconSizeDp.toFloat(), TypedValue.COMPLEX_UNIT_DIP)
        }

        views.setImageViewBitmap(R.id.widget_app_icon, circularAppIconBitmap(context, iconSizeDp))
    }

    /// Compõe fundo azul + logo (face sem fundo) e aplica máscara circular.
    private fun circularAppIconBitmap(context: Context, sizeDp: Int): Bitmap {
        val density = context.resources.displayMetrics.density
        val sizePx = (sizeDp * density).toInt().coerceAtLeast(1)

        val square = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(square)

        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = context.getColor(R.color.ic_launcher_background)
        canvas.drawRect(0f, 0f, sizePx.toFloat(), sizePx.toFloat(), paint)

        val face = BitmapFactory.decodeResource(context.resources, R.drawable.widget_app_face)
        if (face != null) {
            val inset = (sizePx * 0.14f).toInt()
            val dest = Rect(inset, inset, sizePx - inset, sizePx - inset)
            canvas.drawBitmap(face, null, dest, paint)
        } else {
            val foreground = ContextCompat.getDrawable(context, R.drawable.ic_launcher_foreground)
            if (foreground != null) {
                val inset = (sizePx * 0.10f).toInt()
                foreground.setBounds(inset, inset, sizePx - inset, sizePx - inset)
                foreground.draw(canvas)
            }
        }

        val output = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val outCanvas = Canvas(output)
        paint.shader = BitmapShader(square, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        outCanvas.drawCircle(sizePx / 2f, sizePx / 2f, sizePx / 2f, paint)

        square.recycle()
        return output
    }

    /// Overlay de resultado (mensagem grande), com tamanho e alpha controlados.
    private fun resultViews(
        context: Context,
        widgetId: Int,
        text: String,
        color: Int,
        sizeSp: Float,
        alpha: Float,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.magic_task_widget)

        views.setViewVisibility(R.id.widget_main_row, View.GONE)
        views.setViewVisibility(R.id.widget_result, View.VISIBLE)
        views.setTextViewText(R.id.widget_result, text)
        views.setTextColor(R.id.widget_result, color)
        views.setTextViewTextSize(R.id.widget_result, TypedValue.COMPLEX_UNIT_SP, sizeSp)
        views.setAlphaCompat(R.id.widget_result, alpha)

        // Mantém o clique funcionando mesmo durante o resultado.
        views.setOnClickPendingIntent(R.id.widget_root, openInputIntent(context, widgetId))

        return views
    }

    // ---------------------------------------------------------------------------
    // Animação: pop in → hold → fade out → volta (fade in) ao estado inicial
    // ---------------------------------------------------------------------------

    private fun animateResult(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        success: Boolean,
    ) {
        animatingIds.add(widgetId)

        val text = context.getString(
            if (success) R.string.widget_success else R.string.widget_error,
        )
        val color = if (success) Color.parseColor("#1FA463") else Color.parseColor("#E5484D")
        val handler = Handler(Looper.getMainLooper())

        fun push(views: RemoteViews) {
            try {
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                Log.e(TAG, "Falha no frame da animação $widgetId", e)
            }
        }

        // Pop in: começa pequeno e transparente, cresce e estabiliza.
        push(resultViews(context, widgetId, text, color, 14f, 0f))
        handler.postDelayed({ push(resultViews(context, widgetId, text, color, 30f, 1f)) }, 40)
        handler.postDelayed({ push(resultViews(context, widgetId, text, color, 24f, 1f)) }, 140)
        handler.postDelayed({ push(resultViews(context, widgetId, text, color, 26f, 1f)) }, 220)

        // Fade out.
        handler.postDelayed({ push(resultViews(context, widgetId, text, color, 26f, 0.7f)) }, 1300)
        handler.postDelayed({ push(resultViews(context, widgetId, text, color, 26f, 0.4f)) }, 1380)
        handler.postDelayed({ push(resultViews(context, widgetId, text, color, 26f, 0.15f)) }, 1460)
        handler.postDelayed({ push(resultViews(context, widgetId, text, color, 26f, 0f)) }, 1540)

        // Volta ao estado inicial com fade in.
        handler.postDelayed({ push(rowViews(context, appWidgetManager, widgetId, loading = false, alpha = 0f)) }, 1600)
        handler.postDelayed({ push(rowViews(context, appWidgetManager, widgetId, loading = false, alpha = 0.4f)) }, 1680)
        handler.postDelayed({ push(rowViews(context, appWidgetManager, widgetId, loading = false, alpha = 0.75f)) }, 1760)
        handler.postDelayed({
            push(rowViews(context, appWidgetManager, widgetId, loading = false, alpha = 1f))
            animatingIds.remove(widgetId)
        }, 1840)
    }

    private fun RemoteViews.setAlphaCompat(viewId: Int, alpha: Float) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            setFloat(viewId, "setAlpha", alpha)
        }
    }

    companion object {
        private const val TAG = "MagicTaskWidget"

        const val STATUS_KEY = "widget_status"
        const val STATUS_LOADING = "loading"
        const val STATUS_SUCCESS = "success"
        const val STATUS_ERROR = "error"

        private const val WIDGET_PADDING_DP = 10

        /// Widgets atualmente em animação — evita que refreshes do sistema
        /// interrompam a sequência de frames.
        private val animatingIds = mutableSetOf<Int>()

        /// Força atualização imediata de todas as instâncias do widget.
        fun requestUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, MagicTaskWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            val intent = Intent(context, MagicTaskWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }
}

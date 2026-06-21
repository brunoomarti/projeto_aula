package com.tasker.project

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText

/// Dialogo leve para digitar a tarefa — não abre a UI Flutter completa.
class MagicTaskWidgetInputActivity : Activity() {

  private lateinit var input: EditText

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_widget_input)

    input = findViewById(R.id.dialog_task_input)
    val submit = findViewById<Button>(R.id.dialog_submit_button)
    val cancel = findViewById<Button>(R.id.dialog_cancel_button)

    input.requestFocus()
    input.post { showKeyboard(input) }

    fun submitTask() {
      val text = input.text?.toString()?.trim().orEmpty()
      if (text.isEmpty()) {
        input.error = "Digite uma tarefa"
        return
      }
      dispatchTask(text)
      finish()
    }

    submit.setOnClickListener { submitTask() }
    cancel.setOnClickListener { finish() }

    input.setOnEditorActionListener { _, actionId, _ ->
      if (actionId == EditorInfo.IME_ACTION_DONE) {
        submitTask()
        true
      } else {
        false
      }
    }
  }

  override fun onWindowFocusChanged(hasFocus: Boolean) {
    super.onWindowFocusChanged(hasFocus)
    // Ao abrir pelo widget, o teclado só aparece depois que a janela ganha foco.
    if (hasFocus && ::input.isInitialized) {
      input.requestFocus()
      showKeyboard(input)
    }
  }

  private fun showKeyboard(target: EditText) {
    val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
    imm.showSoftInput(target, InputMethodManager.SHOW_IMPLICIT)
  }

  private fun dispatchTask(text: String) {
    Log.d(TAG, "Enviando tarefa do dialog (${text.length} chars)")

    val saved = getSharedPreferences(HOME_WIDGET_PREFS, MODE_PRIVATE)
      .edit()
      .putString(PENDING_TASK_TEXT_KEY, text)
      .putString(MagicTaskWidgetProvider.STATUS_KEY, MagicTaskWidgetProvider.STATUS_LOADING)
      .commit()

    if (!saved) {
      Log.e(TAG, "Falha ao gravar texto no SharedPreferences")
    }

    // Mostra o loading no widget imediatamente.
    MagicTaskWidgetProvider.requestUpdate(this)

    WidgetFlutterWorker.processPendingTask(this, text)
    finish()
  }

  companion object {
    private const val TAG = "MagicTaskWidgetInput"
    private const val HOME_WIDGET_PREFS = "HomeWidgetPreferences"
    private const val PENDING_TASK_TEXT_KEY = "pending_task_text"
  }
}

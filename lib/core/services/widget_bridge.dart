import 'package:flutter/services.dart';

/// Ponte nativa ↔ Dart para processamento headless do widget.
class WidgetBridge {
  WidgetBridge._();

  static const _channel = MethodChannel('com.tasker.project/widget_bridge');

  static Future<String> consumePendingText() async {
    try {
      final text = await _channel.invokeMethod<String>('consumePendingText');
      return text?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> finishActivity() async {
    try {
      await _channel.invokeMethod<void>('finish');
    } catch (_) {
      // Engine headless já encerrado.
    }
  }
}

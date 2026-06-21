import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'widget_task_handler.dart' show homeWidgetBackgroundCallback;

/// Configura o widget de tarefa rápida na home do Android.
class HomeWidgetService {
  HomeWidgetService._();

  static bool _registered = false;

  static Future<void> initialize() async {
    if (_registered) return;

    try {
      await HomeWidget.setAppGroupId('group.com.tasker.project');
      await HomeWidget.registerInteractivityCallback(
        homeWidgetBackgroundCallback,
      );
      _registered = true;
      debugPrint('HomeWidgetService: callback registrado.');
    } catch (e, st) {
      debugPrint('HomeWidgetService.initialize: $e\n$st');
    }
  }
}

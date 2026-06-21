import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import '../../app/app_navigator.dart';
import '../../features/tasks/presentation/pages/task_detail_page.dart';
import '../../features/tasks/presentation/state/task_store.dart';

/// Abre [TaskDetailPage] ao tocar em notificação de tarefa criada.
class TaskNotificationRouter {
  TaskNotificationRouter._();

  static const taskPayloadPrefix = 'task:';

  static String? _pendingTaskId;

  static String payloadForTask(String taskId) => '$taskPayloadPrefix$taskId';

  static String? taskIdFromPayload(String? payload) {
    if (payload == null || !payload.startsWith(taskPayloadPrefix)) return null;
    final id = payload.substring(taskPayloadPrefix.length).trim();
    return id.isEmpty ? null : id;
  }

  static void handleNotificationResponse(NotificationResponse response) {
    final taskId = taskIdFromPayload(response.payload);
    if (taskId == null) return;
    _pendingTaskId = taskId;
    unawaited(tryOpenPendingTask());
  }

  static Future<void> consumeLaunchNotification() async {
    final plugin = FlutterLocalNotificationsPlugin();
    final details = await plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return;
    final response = details?.notificationResponse;
    if (response == null) return;
    handleNotificationResponse(response);
  }

  /// Chamado quando o app está autenticado e pronto (ex.: [AppShell] montado).
  static Future<void> tryOpenPendingTask() async {
    final taskId = _pendingTaskId;
    if (taskId == null) return;

    final nav = rootNavigatorKey.currentState;
    final context = rootNavigatorKey.currentContext;
    if (nav == null || context == null) return;

    final store = context.read<TaskStore>();
    if (!store.isInitialized) return;

    await store.refreshFromDisk();
    final task = store.taskById(taskId);
    if (task == null) {
      debugPrint('TaskNotificationRouter: tarefa $taskId não encontrada');
      return;
    }

    _pendingTaskId = null;

    await nav.push<void>(
      MaterialPageRoute<void>(
        builder: (context) => TaskDetailPage(task: task),
      ),
    );
  }
}

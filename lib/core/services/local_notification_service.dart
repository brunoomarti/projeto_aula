import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/tasks/domain/task.dart';
import '../navigation/task_notification_router.dart';
import 'widget_task_handler.dart';

/// Notificações locais (Android) — ícone `@mipmap/ic_launcher` + cor primária.
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static const _channelId = 'tasker_default';
  static const _channelName = 'Tasker';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse:
          TaskNotificationRouter.handleNotificationResponse,
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Notificações do Tasker',
      importance: Importance.high,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(channel);
    // Em engine headless (widget) não há Activity, então requestNotificationsPermission
    // lança NullPointerException. Ignoramos — a permissão já foi concedida no app.
    try {
      await android?.requestNotificationsPermission();
    } catch (_) {}

    _initialized = true;
  }

  /// Exibe notificação quando uma tarefa é criada (ex.: widget da home).
  Future<void> showTaskCreated({required Task task}) async {
    await initialize();

    final summary = WidgetTaskHandler.formatTaskSummary(task);

    final details = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Notificações do Tasker',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF2864F0),
      styleInformation: BigTextStyleInformation(summary),
    );

    await _plugin.show(
      (task.id.hashCode & 0x7FFFFFFF) + 1,
      'Tarefa criada',
      summary,
      NotificationDetails(android: details),
      payload: TaskNotificationRouter.payloadForTask(task.id),
    );
  }
}

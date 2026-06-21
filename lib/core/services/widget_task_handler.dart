import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../config/env_loader.dart';
import '../../features/tasks/data/task_local_repository.dart';
import '../../features/tasks/domain/task.dart';
import 'local_notification_service.dart';
import 'magic_task_builder.dart';

/// Processa tarefas enviadas pelo widget da home (Android) em background.
class WidgetTaskHandler {
  WidgetTaskHandler._();

  static const pendingTextKey = 'pending_task_text';
  static const statusKey = 'widget_status';
  static const lastTaskTitleKey = 'widget_last_task_title';

  // Tokens de status lidos pelo provider nativo para renderizar/animar o widget.
  static const statusLoading = 'loading';
  static const statusSuccess = 'success';
  static const statusError = 'error';

  static const androidProviderName = 'MagicTaskWidgetProvider';

  /// Processa URI `taskerWidget://createTask` vinda do widget Android.
  static Future<void> handleBackgroundUri(Uri? uri) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (uri?.host != 'createTask') return;

    await loadEnv();
    await initializeDateFormatting('pt_BR');
    await LocalNotificationService.instance.initialize();
    await processPendingTask();
  }

  static Future<void> processPendingTask() async {
    final raw = await HomeWidget.getWidgetData<String>(
      pendingTextKey,
      defaultValue: '',
    );
    await processPendingTaskWithText(raw?.trim() ?? '');
  }

  static Future<void> processPendingTaskWithText(String text) async {
    try {
      debugPrint('WidgetTaskHandler: processando "$text"');
      if (text.isEmpty) {
        debugPrint('WidgetTaskHandler: texto vazio, ignorando.');
        return;
      }

      await HomeWidget.saveWidgetData<String>(pendingTextKey, '');
      await HomeWidget.saveWidgetData<String>(statusKey, statusLoading);
      await _refreshWidget();

      final task = await createTaskFromText(text);
      debugPrint('WidgetTaskHandler: tarefa criada "${task.title}"');
      await _persistTask(task);

      // Notificação é "best-effort": falha aqui não invalida a tarefa criada.
      try {
        await LocalNotificationService.instance.showTaskCreated(task: task);
      } catch (e, st) {
        debugPrint('WidgetTaskHandler: notificação falhou: $e\n$st');
      }

      await HomeWidget.saveWidgetData<String>(statusKey, statusSuccess);
      await HomeWidget.saveWidgetData<String>(lastTaskTitleKey, task.title);
      await _refreshWidget();
    } catch (e, st) {
      debugPrint('WidgetTaskHandler.processPendingTask: $e\n$st');
      await HomeWidget.saveWidgetData<String>(statusKey, statusError);
      await _refreshWidget();
    }
  }

  /// Interpreta texto do widget — mesma lógica do [MagicTaskInput] (Gemini quando
  /// configurado), sem GPS em background.
  @visibleForTesting
  static Future<Task> createTaskFromText(String text) async {
    await loadEnv();
    await initializeDateFormatting('pt_BR');
    return MagicTaskBuilder.buildFromText(
      text: text,
      resolveLocation: false,
    );
  }

  static Future<void> _persistTask(Task task) async {
    final pending = task.copyWith(synced: false);
    await TaskLocalRepository.instance.addTask(pending);
  }

  static Future<void> _refreshWidget() async {
    try {
      await HomeWidget.updateWidget(name: androidProviderName);
    } catch (e, st) {
      debugPrint('WidgetTaskHandler._refreshWidget: $e\n$st');
    }
  }

  /// Formata detalhes da tarefa para notificação / widget.
  static String formatTaskSummary(Task task) {
    final parts = <String>[task.title.trim()];
    if (task.data.isNotEmpty) {
      parts.add(_formatDateLabel(task.data));
    }
    if (task.hora.isNotEmpty) {
      parts.add('às ${task.hora}');
    }
    if (task.location?.name?.isNotEmpty == true) {
      parts.add('📍 ${task.location!.name}');
    } else if (task.descricao.trim().isNotEmpty) {
      parts.add(task.descricao.trim());
    }
    return parts.where((p) => p.isNotEmpty).join(' · ');
  }

  static String _formatDateLabel(String ymd) {
    try {
      final parts = ymd.split('-');
      if (parts.length != 3) return ymd;
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final dateOnly = DateTime(date.year, date.month, date.day);
      if (dateOnly == todayOnly) return 'hoje';
      if (dateOnly == todayOnly.add(const Duration(days: 1))) {
        return 'amanhã';
      }
      return DateFormat('d/M', 'pt_BR').format(date);
    } catch (_) {
      return ymd;
    }
  }
}

/// Entry point registrado pelo [HomeWidget.registerInteractivityCallback].
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  await WidgetTaskHandler.handleBackgroundUri(uri);
}

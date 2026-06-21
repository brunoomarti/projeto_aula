import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app/app_navigator.dart';
import 'app/app_route_observer.dart';
import 'app/theme/tasker_colors.dart';
import 'app/theme/tasker_theme.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/config/env_loader.dart';
import 'core/performance/app_animation_warmup.dart';
import 'core/services/connectivity_notifier.dart';
import 'core/services/home_widget_service.dart';
import 'core/services/local_data_migration.dart';
import 'core/services/local_notification_service.dart';
import 'core/navigation/task_notification_router.dart';
import 'core/services/widget_bridge.dart';
import 'core/services/widget_task_handler.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/widgets/auth_gate.dart';
import 'features/profile/data/profile_supabase_repository.dart';
import 'features/tasks/data/task_supabase_repository.dart';
import 'features/gamification/presentation/state/daily_combo_controller.dart';
import 'features/achievements/presentation/state/achievement_controller.dart';
import 'features/tasks/presentation/state/task_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.scheduleWarmUpFrame();
  unawaited(HomeWidgetService.initialize());
  runApp(const _AppLoader());
}

/// Entry point headless do widget — fica em `main.dart` para não sofrer
/// tree-shaking. Acionado por [WidgetFlutterWorker] (Android, sem UI).
@pragma('vm:entry-point')
void widgetTaskEntryPoint() {
  WidgetsFlutterBinding.ensureInitialized();
  _runWidgetTask();
}

Future<void> _runWidgetTask() async {
  try {
    await loadEnv();
    await initializeDateFormatting('pt_BR');
    final text = await WidgetBridge.consumePendingText();
    if (text.isEmpty) {
      debugPrint('widgetTaskEntryPoint: texto vazio do nativo');
      return;
    }
    await WidgetTaskHandler.processPendingTaskWithText(text);
  } catch (e, st) {
    debugPrint('widgetTaskEntryPoint: $e\n$st');
  } finally {
    await WidgetBridge.finishActivity();
  }
}

/// Mostra splash na 1ª frame; Firebase/Supabase carregam em background.
class _AppLoader extends StatefulWidget {
  const _AppLoader();

  @override
  State<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<_AppLoader> {
  Widget? _app;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await loadEnv();
      await initializeDateFormatting('pt_BR');
      await LocalNotificationService.instance.initialize();
      await TaskNotificationRouter.consumeLaunchNotification();
      await HomeWidgetService.initialize();
      await AppBootstrap.initialize();

      final taskRepository = TaskSupabaseRepository();
      final profileRepository = ProfileSupabaseRepository();
      final migration = LocalDataMigration(
        taskRepository: taskRepository,
        profileRepository: profileRepository,
      );

      final authController = AuthController(
        profileRepository: profileRepository,
        migration: migration,
      );
      final taskStore = TaskStore(repository: taskRepository);
      final dailyComboController = DailyComboController(taskStore: taskStore);
      final achievementController =
          AchievementController(taskStore: taskStore);
      final connectivityNotifier = ConnectivityNotifier();

      if (!mounted) return;

      WidgetsBinding.instance.scheduleWarmUpFrame();
      await AppAnimationWarmup.waitForFrames(6);

      if (!mounted) return;
      setState(() {
        _app = MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: authController),
            ChangeNotifierProvider<TaskStore>.value(value: taskStore),
            ChangeNotifierProvider<DailyComboController>.value(
              value: dailyComboController,
            ),
            ChangeNotifierProvider<AchievementController>.value(
              value: achievementController,
            ),
            ChangeNotifierProvider<ConnectivityNotifier>.value(
              value: connectivityNotifier,
            ),
          ],
          child: const TaskerApp(),
        );
      });

      unawaited(authController.initialize());
    } catch (e, st) {
      debugPrint('bootstrap: $e\n$st');
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return StartupErrorApp(message: _error!);
    }
    if (_app != null) {
      return _app!;
    }
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _BootSplash(),
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: TaskerColors.appBackground,
      body: Stack(
        alignment: Alignment.center,
        children: [
          AppAnimationWarmupPanel(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tasker',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: TaskerColors.primary,
                ),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Exibido quando Firebase/Supabase/.env falham antes do app abrir.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: TaskerTheme.light,
      home: Scaffold(
        backgroundColor: TaskerColors.appBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Não foi possível iniciar o Tasker',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: TaskerColors.primaryText,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: TaskerColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verifique .env, Firebase (google-services.json) e Supabase. '
                  'Depois rode flutter run de novo.',
                  style: TextStyle(fontSize: 13, color: TaskerColors.mutedText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TaskerApp extends StatelessWidget {
  const TaskerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tasker',
      navigatorKey: rootNavigatorKey,
      theme: TaskerTheme.light,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorObservers: [appRouteObserver],
      home: const AuthGate(),
    );
  }
}

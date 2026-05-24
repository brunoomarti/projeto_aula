import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app/app_route_observer.dart';
import 'app/app_shell.dart';
import 'app/theme/tasker_theme.dart';
import 'core/config/env_loader.dart';
import 'features/tasks/presentation/state/task_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadEnv();
  await initializeDateFormatting('pt_BR');

  final taskStore = TaskStore();
  await taskStore.initialize();

  runApp(
    ChangeNotifierProvider<TaskStore>.value(
      value: taskStore,
      child: const TaskerApp(),
    ),
  );
}

class TaskerApp extends StatelessWidget {
  const TaskerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tasker',
      theme: TaskerTheme.light,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorObservers: [appRouteObserver],
      home: const AppShell(),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_shell.dart';
import '../../../../app/theme/tasker_colors.dart';
import '../../../gamification/presentation/state/daily_combo_controller.dart';
import '../../../achievements/presentation/state/achievement_controller.dart';
import '../../../tasks/presentation/state/task_store.dart';
import '../auth_controller.dart';
import '../pages/login_page.dart';

/// Redireciona para login ou app conforme [AuthController].
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _syncingTasks = false;
  AuthStatus? _lastStatus;
  String? _lastTaskUserId;
  bool _authWaitTimedOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 8), () {
        if (!mounted) return;
        final auth = context.read<AuthController>();
        if (auth.status == AuthStatus.unknown) {
          setState(() => _authWaitTimedOut = true);
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthController>();
    final previous = _lastStatus;
    if (previous != auth.status) {
      _lastStatus = auth.status;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_onAuthStatusChanged(previous)),
      );
    }
  }

  Future<void> _onAuthStatusChanged(AuthStatus? previous) async {
    final auth = context.read<AuthController>();
    final store = context.read<TaskStore>();
    final combo = context.read<DailyComboController>();
    final achievements = context.read<AchievementController>();

    if (auth.isGuest) {
      store.setCloudSyncEnabled(false);
      if (!store.isInitialized) {
        setState(() => _syncingTasks = true);
        try {
          await store.reload();
        } finally {
          if (mounted) setState(() => _syncingTasks = false);
        }
      }
      await achievements.disableForGuest();
      return;
    }

    if (!auth.isAuthenticated) {
      store.setCloudSyncEnabled(true);
      if (previous == AuthStatus.authenticated) {
        _lastTaskUserId = null;
        if (store.isInitialized || store.tasks.isNotEmpty) {
          await store.clear();
        }
        await combo.clear();
        await achievements.clear();
      }
      return;
    }

    store.setCloudSyncEnabled(true);

    final userId = auth.firebaseUser?.uid;
    if (userId == null || userId.isEmpty) return;

    final switchedUser =
        _lastTaskUserId != null && _lastTaskUserId != userId;
    final enteringAccount = previous != AuthStatus.authenticated;

    if (switchedUser) {
      await store.clear();
      await combo.clear();
      await achievements.clear();
    }

    if (_syncingTasks) return;
    if (store.isInitialized && !enteringAccount && !switchedUser) return;

    _lastTaskUserId = userId;

    setState(() => _syncingTasks = true);
    try {
      // Aguarda token/migração do Firebase antes do primeiro push ao Supabase.
      var attempts = 0;
      while (auth.isBusy && attempts < 60) {
        await Future.delayed(const Duration(milliseconds: 50));
        attempts++;
      }

      await store.reload();
      await combo.loadForUser(userId);
      await achievements.loadForUser(userId);
      await store.retrySync();
    } finally {
      if (mounted) setState(() => _syncingTasks = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if ((auth.status == AuthStatus.unknown && !_authWaitTimedOut) ||
        _syncingTasks) {
      return Scaffold(
        backgroundColor: TaskerColors.appBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (auth.status == AuthStatus.unknown) ...[
                const SizedBox(height: 16),
                Text(
                  _authWaitTimedOut
                      ? 'Demorando para conectar…'
                      : 'Carregando…',
                  style: TextStyle(
                    color: TaskerColors.secondaryText.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (!auth.canUseApp) {
      return const LoginPage();
    }

    final store = context.watch<TaskStore>();
    if (!store.isInitialized || store.isLoading) {
      return const Scaffold(
        backgroundColor: TaskerColors.appBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const AppShell();
  }
}

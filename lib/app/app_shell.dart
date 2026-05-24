import 'package:flutter/material.dart';

import '../features/home/presentation/pages/home_page.dart';

/// Shell principal — home como tela raiz (perfil e tarefas abrem por [Navigator]).
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const HomePage(),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';

/// Confirma entrada no app sem login e informa as limitações.
Future<bool> showGuestModeDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Continuar sem login',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: TaskerColors.primaryText,
        ),
      ),
      content: const Text(
        'Você pode usar o app localmente, mas algumas funcionalidades '
        'ficam indisponíveis:\n\n'
        '• Criação inteligente (magic input)\n'
        '• Sincronização de tarefas na nuvem\n'
        '• Combo diário na conta\n'
        '• Conquistas e medalhas\n\n'
        'Suas tarefas ficam apenas neste aparelho até você fazer login.',
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: TaskerColors.secondaryText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: TaskerColors.primary,
          ),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Aviso rápido quando o visitante tenta usar o magic input.
Future<void> showGuestFeatureBlockedDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Requer login',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: TaskerColors.primaryText,
        ),
      ),
      content: const Text(
        'A criação inteligente só está disponível com login. '
        'Faça login para usar o magic input e sincronizar suas tarefas.',
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: TaskerColors.secondaryText,
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            backgroundColor: TaskerColors.primary,
          ),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
}

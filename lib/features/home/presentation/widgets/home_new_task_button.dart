import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';

/// Botão fixo acima da lista — abre o formulário completo de nova tarefa.
class HomeNewTaskButton extends StatelessWidget {
  const HomeNewTaskButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  static const _radius = 14.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: const Color(0x0A000000),
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(_radius),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 22,
                  color: TaskerColors.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Nova tarefa',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: TaskerColors.primary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

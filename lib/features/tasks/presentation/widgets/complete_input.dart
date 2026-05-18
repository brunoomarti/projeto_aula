import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';

/// Campo com label — equivalente a `.complete-input` em [tasker-main/src/css/inputs.css].
class CompleteInput extends StatelessWidget {
  const CompleteInput({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: TaskerColors.secondaryText,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        child,
      ],
    );
  }
}

/// Estilo base de `input` / `textarea` do Tasker web.
class TaskerFieldDecoration {
  static InputDecoration decoration({
    String? hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: TaskerColors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: TaskerColors.mutedText),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: TaskerColors.mutedText),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: TaskerColors.primary, width: 1),
        gapPadding: 0,
      ),
      // Web: box-shadow 0 0 0 3px rgba(40, 100, 240, 0.158)
      focusColor: TaskerColors.inputFocusRing,
      hintStyle: const TextStyle(color: TaskerColors.mutedText, fontSize: 14),
    );
  }

  static const TextStyle textStyle = TextStyle(
    fontSize: 14,
    color: TaskerColors.primaryText,
  );
}

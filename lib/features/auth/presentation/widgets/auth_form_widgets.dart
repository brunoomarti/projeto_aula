import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tasker_project/core/icons/tasker_icon.dart';

import '../../../../app/theme/tasker_colors.dart';

/// Paleta local dos formulários de auth (não afeta o restante do app).
abstract final class _AuthFieldColors {
  static const fill = Colors.white;
  static const border = Color(0xFFC8D1E0);
  static const borderFocused = Color(0xFF2864F0);
}

/// Campo pill — login, senha e demais inputs de auth.
class AuthPillTextField extends StatelessWidget {
  const AuthPillTextField({
    super.key,
    this.controller,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.enabled = true,
    this.validator,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.autocorrect = true,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController? controller;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool enabled;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final Widget? suffixIcon;
  final bool autocorrect;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;

  static const double height = 58;
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(999));

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        enabled: enabled,
        validator: validator,
        onFieldSubmitted: onFieldSubmitted,
        autocorrect: autocorrect,
        textCapitalization: textCapitalization,
        scrollPadding: EdgeInsets.only(bottom: keyboardInset + 88),
        textAlignVertical: TextAlignVertical.center,
      style: const TextStyle(
        fontSize: 16,
        color: TaskerColors.primaryText,
        fontWeight: FontWeight.w500,
        height: 1.2,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        suffixIcon: suffixIcon,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 52,
          minHeight: height,
        ),
        filled: true,
        fillColor: _AuthFieldColors.fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 17,
        ),
        hintStyle: TextStyle(
          color: TaskerColors.mutedText.withValues(alpha: 0.92),
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.2,
        ),
        border: const OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: _AuthFieldColors.border, width: 1.25),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: _AuthFieldColors.border, width: 1.25),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(
            color: _AuthFieldColors.borderFocused,
            width: 1.75,
          ),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: TaskerColors.warning),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: TaskerColors.warning, width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 12, height: 1.1),
        constraints: const BoxConstraints(minHeight: height),
      ),
      ),
    );
  }
}

/// Botão primário pill — ação principal (Entrar, Cadastrar).
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: TaskerColors.primary.withValues(alpha: 0.32),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: TaskerColors.primary,
          disabledBackgroundColor:
              TaskerColors.primary.withValues(alpha: 0.55),
          minimumSize: const Size.fromHeight(height),
          shape: const StadiumBorder(),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

/// Botão outline pill — ações secundárias (Criar conta, Voltar).
class AuthOutlineButton extends StatelessWidget {
  const AuthOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(height),
        foregroundColor: TaskerColors.primary,
        backgroundColor: Colors.white.withValues(alpha: 0.72),
        side: const BorderSide(color: TaskerColors.primary, width: 1.25),
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Login / cadastro com Google.
class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({
    super.key,
    required this.onPressed,
    this.busy = false,
  });

  final VoidCallback? onPressed;
  final bool busy;

  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(height),
        foregroundColor: TaskerColors.primaryText,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _AuthFieldColors.border, width: 1.25),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppHugeIcon(
            icon: HugeIcons.strokeRoundedGoogle,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            busy ? 'Aguarde…' : 'Continuar com Google',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Link discreto — continuar sem login.
class AuthGuestLink extends StatelessWidget {
  const AuthGuestLink({
    super.key,
    required this.onPressed,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: TaskerColors.mutedText.withValues(alpha: 0.85),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: const Text('Continuar sem login'),
      ),
    );
  }
}

/// Link de texto centrado — ex.: esqueci a senha.
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: TaskerColors.secondaryText,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

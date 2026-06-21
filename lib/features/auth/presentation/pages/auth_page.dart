import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:tasker_project/core/icons/tasker_icon.dart';

import '../auth_controller.dart';
import '../widgets/auth_form_widgets.dart';
import '../widgets/auth_page_shell.dart';
import '../widgets/guest_mode_dialog.dart';

enum AuthMode { login, register }

/// Login e cadastro compartilham layout, rodapé e transições de conteúdo.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.initialMode = AuthMode.login});

  final AuthMode initialMode;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late AuthMode _mode;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;

  bool get _isLogin => _mode == AuthMode.login;

  bool get _canSubmitLogin =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _emailController.addListener(_onLoginFieldsChanged);
    _passwordController.addListener(_onLoginFieldsChanged);
  }

  void _onLoginFieldsChanged() => setState(() {});

  @override
  void dispose() {
    _emailController.removeListener(_onLoginFieldsChanged);
    _passwordController.removeListener(_onLoginFieldsChanged);
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode mode) {
    if (_mode == mode || context.read<AuthController>().isBusy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _mode = mode);
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    try {
      await auth.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } catch (_) {
      if (!mounted) return;
      _showError(auth.errorMessage, fallback: 'Não foi possível entrar.');
    }
  }

  Future<void> _submitRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    try {
      await auth.registerWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _nameController.text,
      );
    } catch (_) {
      if (!mounted) return;
      _showError(auth.errorMessage, fallback: 'Não foi possível cadastrar.');
    }
  }

  Future<void> _submitGoogle() async {
    final auth = context.read<AuthController>();
    try {
      await auth.signInWithGoogle();
    } catch (_) {
      if (!mounted) return;
      _showError(auth.errorMessage, fallback: 'Não foi possível entrar.');
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Informe um e-mail válido para recuperar a senha.');
      return;
    }
    final auth = context.read<AuthController>();
    try {
      await auth.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enviamos um link de recuperação para o seu e-mail.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showError(auth.errorMessage, fallback: 'Não foi possível enviar o link.');
    }
  }

  void _showError(String? message, {String fallback = 'Algo deu errado.'}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? fallback)),
    );
  }

  Future<void> _continueWithoutLogin() async {
    if (context.read<AuthController>().isBusy) return;
    final confirmed = await showGuestModeDialog(context);
    if (!confirmed || !mounted) return;
    context.read<AuthController>().continueWithoutLogin();
  }

  Widget _buildPasswordVisibilityToggle({
    required bool obscure,
    required bool busy,
    required VoidCallback onToggle,
  }) {
    return IconButton(
      icon: AppHugeIcon(
        icon: obscure
            ? HugeIcons.strokeRoundedEye
            : HugeIcons.strokeRoundedViewOff,
        size: 20,
      ),
      onPressed: busy ? null : onToggle,
    );
  }

  Widget _buildLoginForm({required bool busy}) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthPillTextField(
            controller: _emailController,
            hintText: 'Login',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enabled: !busy,
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty || !value.contains('@')) {
                return 'Informe um e-mail válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          AuthPillTextField(
            controller: _passwordController,
            hintText: 'Senha',
            obscureText: _obscureLoginPassword,
            textInputAction: TextInputAction.done,
            enabled: !busy,
            onFieldSubmitted: (_) => _submitLogin(),
            suffixIcon: _buildPasswordVisibilityToggle(
              obscure: _obscureLoginPassword,
              busy: busy,
              onToggle: () =>
                  setState(() => _obscureLoginPassword = !_obscureLoginPassword),
            ),
            validator: (v) {
              if ((v ?? '').length < 6) {
                return 'Mínimo de 6 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          AuthTextLink(
            label: 'Esqueceu sua senha?',
            onPressed: busy ? null : _resetPassword,
          ),
          const SizedBox(height: 22),
          AuthPrimaryButton(
            label: 'Entrar',
            busy: busy,
            onPressed: busy || !_canSubmitLogin ? null : _submitLogin,
          ),
          const SizedBox(height: 14),
          AuthGoogleButton(
            busy: busy,
            onPressed: _submitGoogle,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm({required bool busy}) {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthPillTextField(
            controller: _nameController,
            hintText: 'Nome completo',
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            autocorrect: false,
            enabled: !busy,
            validator: (v) {
              final parts = (v ?? '')
                  .trim()
                  .split(RegExp(r'\s+'))
                  .where((part) => part.isNotEmpty)
                  .toList();
              if (parts.length < 2) {
                return 'Informe nome e sobrenome';
              }
              if (parts.any((part) => part.length < 2)) {
                return 'Nome inválido';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          AuthPillTextField(
            controller: _emailController,
            hintText: 'E-mail',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enabled: !busy,
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty || !value.contains('@')) {
                return 'Informe um e-mail válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          AuthPillTextField(
            controller: _passwordController,
            hintText: 'Senha',
            obscureText: _obscureRegisterPassword,
            textInputAction: TextInputAction.next,
            enabled: !busy,
            suffixIcon: _buildPasswordVisibilityToggle(
              obscure: _obscureRegisterPassword,
              busy: busy,
              onToggle: () => setState(
                () => _obscureRegisterPassword = !_obscureRegisterPassword,
              ),
            ),
            validator: (v) {
              if ((v ?? '').length < 6) {
                return 'Mínimo de 6 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          AuthPillTextField(
            controller: _confirmController,
            hintText: 'Confirmar senha',
            obscureText: _obscureRegisterPassword,
            textInputAction: TextInputAction.done,
            enabled: !busy,
            onFieldSubmitted: (_) => _submitRegister(),
            validator: (v) {
              if (v != _passwordController.text) {
                return 'As senhas não coincidem';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          AuthPrimaryButton(
            label: 'Cadastrar',
            busy: busy,
            onPressed: _submitRegister,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final busy = auth.isBusy;

    return AuthPageShell(
      contentKey: _mode,
      scrollController: _scrollController,
      title: _isLogin ? 'Seja bem-vindo!' : 'Crie sua conta',
      subtitle: _isLogin
          ? 'Faça seu login'
          : 'Comece a organizar suas tarefas',
      footerKey: _mode,
      footer: _isLogin
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AuthOutlineButton(
                  label: 'Criar uma conta',
                  onPressed: busy ? null : () => _switchMode(AuthMode.register),
                ),
                const SizedBox(height: 4),
                AuthGuestLink(
                  onPressed: busy ? null : _continueWithoutLogin,
                ),
              ],
            )
          : AuthOutlineButton(
              label: 'Já tenho conta',
              onPressed: busy ? null : () => _switchMode(AuthMode.login),
            ),
      child: _isLogin
          ? _buildLoginForm(busy: busy)
          : _buildRegisterForm(busy: busy),
    );
  }
}

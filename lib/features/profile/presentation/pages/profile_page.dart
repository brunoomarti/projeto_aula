import 'package:flutter/material.dart';
import 'package:tasker_project/core/icons/tasker_icon.dart';

import 'package:hugeicons/hugeicons.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/tasker_card_style.dart';
import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/layout/tasker_breakpoints.dart';
import '../../../../core/widgets/profile_initials_avatar.dart';
import '../../../../core/widgets/tasker_floating_page_shell.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../tasks/presentation/widgets/complete_input.dart';
import '../../../tasks/presentation/widgets/task_page_header.dart';
import '../../../tasks/presentation/widgets/task_section_card.dart';
import 'profile_edit_page.dart';

/// Perfil na nuvem (Supabase) — nome usado no [UserDock].
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final auth = context.read<AuthController>();
    if (!auth.isGuest) {
      await auth.reloadProfile();
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ProfileEditPage()),
    );
    if (!mounted) return;
    await reload();
  }

  Future<void> _signOut() async {
    final auth = context.read<AuthController>();
    final isGuest = auth.isGuest;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isGuest ? 'Voltar ao login?' : 'Sair da conta?'),
        content: Text(
          isGuest
              ? 'Suas tarefas locais permanecem neste aparelho. '
                  'Faça login para sincronizar na nuvem.'
              : 'Suas tarefas continuam salvas na nuvem. '
                  'Você pode entrar novamente quando quiser.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await context.read<AuthController>().signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final email = auth.profile?.email;
    final displayName = auth.displayName;
    final avatarUrl = auth.avatarUrl;
    final initials = profileInitialsFromName(displayName);
    final dateLabel =
        DateFormat("d 'de' MMMM", 'pt_BR').format(DateTime.now());

    return Scaffold(
      backgroundColor: TaskerColors.appBackground,
      body: TaskerFloatingPageShell(
        headerReserve: TaskPageHeaderBar.reserveHeight(context),
        header: TaskPageHeaderBar(
          title: 'Meu perfil',
          subtitle: 'Personalize como você aparece no app',
          onBack: () => Navigator.of(context).pop(),
        ),
        bodyBuilder: (context, insets) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final pagePadding = TaskerBreakpoints.pagePadding(width);
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  pagePadding.left,
                  insets.top,
                  pagePadding.right,
                  insets.bottom,
                ),
                child: TaskerResponsiveContent(
                  width: width,
                  child: _buildBody(
                    email: email,
                    displayName: displayName,
                    avatarUrl: avatarUrl,
                    initials: initials,
                    dateLabel: dateLabel,
                    isGuest: auth.isGuest,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBody({
    required String? email,
    required String displayName,
    required String? avatarUrl,
    required String initials,
    required String dateLabel,
    required bool isGuest,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileIdentityCard(
          initials: initials,
          displayName: displayName,
          avatarUrl: avatarUrl,
          dateLabel: dateLabel,
          onEdit: isGuest ? null : _openEditProfile,
        ),
        if (isGuest) ...[
          const SizedBox(height: TaskerCardStyle.sectionSpacing),
          TaskSectionCard(
            title: 'Modo visitante',
            icon: HugeIcons.strokeRoundedUserWarning01,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Você está usando o app sem login. Tarefas ficam só '
                  'neste aparelho e a criação inteligente não está disponível.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: TaskerColors.secondaryText.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (!isGuest) ...[
          const SizedBox(height: TaskerCardStyle.sectionSpacing),
          TaskSectionCard(
            title: 'Identificação',
            icon: HugeIcons.strokeRoundedIdentification,
            child: email != null && email.isNotEmpty
                ? CompleteInput(
                    label: 'E-mail',
                    child: Text(
                      email,
                      style: TaskerFieldDecoration.textStyle.copyWith(
                        color: TaskerColors.secondaryText,
                      ),
                    ),
                  )
                : Text(
                    'Nenhum e-mail vinculado à conta.',
                    style: TextStyle(
                      fontSize: 14,
                      color: TaskerColors.secondaryText.withValues(alpha: 0.95),
                    ),
                  ),
          ),
          const SizedBox(height: TaskerCardStyle.sectionSpacing),
          TaskSectionCard(
            title: 'Conta',
            icon: HugeIcons.strokeRoundedCloud,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Suas tarefas são sincronizadas com sua conta '
                  '(Firebase + Supabase).',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: TaskerColors.secondaryText.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 16),
                _SignOutButton(onPressed: _signOut),
              ],
            ),
          ),
        ],
        if (isGuest) ...[
          const SizedBox(height: TaskerCardStyle.sectionSpacing),
          _SignOutButton(
            onPressed: _signOut,
            label: 'Fazer login',
            icon: HugeIcons.strokeRoundedLogin01,
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Card do perfil na home — toque abre a edição.
class _ProfileIdentityCard extends StatelessWidget {
  const _ProfileIdentityCard({
    required this.initials,
    required this.displayName,
    required this.dateLabel,
    this.avatarUrl,
    this.onEdit,
  });

  final String initials;
  final String displayName;
  final String dateLabel;
  final String? avatarUrl;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return TaskSectionCardShell(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: TaskerColors.appBackground,
          borderRadius:
              BorderRadius.circular(TaskerCardStyle.innerTileRadius),
        ),
        child: Row(
          children: [
            ProfileAvatar(
              initials: initials,
              imageUrl: avatarUrl,
              size: 52,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: TaskerColors.primaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      color: TaskerColors.secondaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (onEdit != null) ...[
              AppHugeIcon(
                icon: HugeIcons.strokeRoundedEdit01,
                size: 22,
                color: TaskerColors.primary.withValues(alpha: 0.85),
              ),
            ] else
              const SizedBox(width: 22),
          ],
        ),
      ),
    );
  }
}

/// Botão secundário em tom de warning.
class _SignOutButton extends StatelessWidget {
  const _SignOutButton({
    required this.onPressed,
    this.label = 'Sair da conta',
    this.icon = HugeIcons.strokeRoundedLogout01,
  });

  final VoidCallback? onPressed;
  final String label;
  final List<List<dynamic>> icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: AppHugeIcon(icon: icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: TaskerColors.warning.withValues(alpha: 0.12),
        foregroundColor: TaskerColors.warning,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

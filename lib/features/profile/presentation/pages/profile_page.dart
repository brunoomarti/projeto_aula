import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/tasker_card_style.dart';
import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/layout/tasker_breakpoints.dart';
import '../../../../core/services/user_local_service.dart';
import '../../../../core/widgets/profile_initials_avatar.dart';
import '../../../tasks/presentation/widgets/complete_input.dart';
import '../../../tasks/presentation/widgets/task_page_header.dart';
import '../../../tasks/presentation/widgets/task_section_card.dart';

/// Perfil local (sem nuvem) — nome usado no [UserDock].
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.onNameSaved,
  });

  final VoidCallback? onNameSaved;

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    reload();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  Future<void> reload() async {
    final name = await UserLocalService.getDisplayName();
    if (!mounted) return;
    setState(() {
      _nameController.text = name ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    await UserLocalService.setDisplayName(_nameController.text);
    widget.onNameSaved?.call();

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nome salvo no dispositivo.')),
    );
  }

  String get _previewName {
    final trimmed = _nameController.text.trim();
    return trimmed.isEmpty ? 'Usuário' : trimmed;
  }

  String get _initials => profileInitialsFromName(_nameController.text);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaskerColors.appBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TaskPageHeaderBar(
            title: 'Meu perfil',
            subtitle: 'Personalize como você aparece no app',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      return SingleChildScrollView(
                        padding: TaskerBreakpoints.pagePadding(width),
                        child: TaskerResponsiveContent(
                          width: width,
                          child: _buildBody(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final dateLabel =
        DateFormat("d 'de' MMMM", 'pt_BR').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfilePreviewCard(
          initials: _initials,
          displayName: _previewName,
          dateLabel: dateLabel,
        ),
        const SizedBox(height: TaskerCardStyle.sectionSpacing),
        TaskSectionCard(
          title: 'Identificação',
          icon: Icons.badge_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CompleteInput(
                label: 'Nome',
                child: TextField(
                  controller: _nameController,
                  enabled: !_saving,
                  decoration: TaskerFieldDecoration.decoration(
                    hintText: 'Como devemos te chamar?',
                  ),
                  style: TaskerFieldDecoration.textStyle,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(height: 16),
              _SaveButton(
                onPressed: _saving ? null : _save,
                loading: _saving,
              ),
            ],
          ),
        ),
        const SizedBox(height: TaskerCardStyle.sectionSpacing),
        TaskSectionCard(
          title: 'Privacidade',
          icon: Icons.phonelink_lock_outlined,
          child: Text(
            'Seu nome fica salvo apenas neste dispositivo. '
            'Nada é enviado para a nuvem.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: TaskerColors.secondaryText.withValues(alpha: 0.95),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Pré-visualização do cabeçalho da home ([UserDock]).
class _ProfilePreviewCard extends StatelessWidget {
  const _ProfilePreviewCard({
    required this.initials,
    required this.displayName,
    required this.dateLabel,
  });

  final String initials;
  final String displayName;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return TaskSectionCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined,
                  size: 20, color: TaskerColors.primary),
              const SizedBox(width: 8),
              Text('Pré-visualização', style: TaskerCardStyle.sectionTitle),
            ],
          ),
          const SizedBox(height: TaskerCardStyle.sectionHeaderGap),
          Text(
            'Assim você aparece na tela inicial',
            style: TextStyle(
              fontSize: 13,
              color: TaskerColors.secondaryText.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: TaskerColors.appBackground,
              borderRadius:
                  BorderRadius.circular(TaskerCardStyle.innerTileRadius),
            ),
            child: Row(
              children: [
                ProfileInitialsAvatar(initials: initials, size: 52),
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
                const SizedBox(width: 52),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.onPressed,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: TaskerColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'Salvar nome',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
    );
  }
}

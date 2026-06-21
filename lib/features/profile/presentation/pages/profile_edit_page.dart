import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:tasker_project/core/icons/tasker_icon.dart';

import '../../../../app/theme/tasker_card_style.dart';
import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/layout/tasker_breakpoints.dart';
import '../../../../core/widgets/profile_initials_avatar.dart';
import '../../../../core/widgets/tasker_floating_page_shell.dart';
import '../../../../core/widgets/tasker_glass_footer_bar.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../tasks/presentation/widgets/complete_input.dart';
import '../../../tasks/presentation/widgets/task_page_header.dart';
import '../../../tasks/presentation/widgets/task_section_card.dart';
import '../utils/profile_avatar_picker.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _nameController = TextEditingController();

  Uint8List? _pickedAvatarBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _nameController.text = auth.profile?.displayName ?? auth.displayName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _initials => profileInitialsFromName(_nameController.text);

  Future<void> _pickAvatar() async {
    if (_saving) return;
    try {
      final bytes = await pickAndCropProfileAvatar(context);
      if (bytes == null || !mounted) return;
      setState(() => _pickedAvatarBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(profileAvatarPickErrorMessage(e))),
      );
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe seu nome.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<AuthController>().updateProfileDetails(
            displayName: name,
            avatarBytes: _pickedAvatarBytes,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = context.watch<AuthController>().avatarUrl;

    return Scaffold(
      backgroundColor: TaskerColors.appBackground,
      body: TaskerFloatingPageShell(
        headerReserve: TaskPageHeaderBar.reserveHeight(context),
        header: TaskPageHeaderBar(
          title: 'Editar perfil',
          subtitle: 'Foto e nome exibidos no app',
          onBack: _saving ? null : () => Navigator.of(context).pop(),
        ),
        footer: TaskerGlassFooterBar(
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: TaskerColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Salvar alterações',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        bodyBuilder: (context, insets) {
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TaskSectionCard(
                        title: 'Foto de perfil',
                        icon: HugeIcons.strokeRoundedImage01,
                        child: Column(
                          children: [
                            _EditableAvatar(
                              initials: _initials,
                              imageUrl: avatarUrl,
                              pickedBytes: _pickedAvatarBytes,
                              onTap: _pickAvatar,
                              enabled: !_saving,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Toque na foto para escolher e recortar',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: TaskerColors.secondaryText
                                    .withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: TaskerCardStyle.sectionSpacing),
                      TaskSectionCard(
                        title: 'Nome',
                        icon: HugeIcons.strokeRoundedUser,
                        child: CompleteInput(
                          label: 'Como devemos te chamar?',
                          child: TextField(
                            controller: _nameController,
                            enabled: !_saving,
                            decoration: TaskerFieldDecoration.decoration(
                              hintText: 'Seu nome completo',
                            ),
                            style: TaskerFieldDecoration.textStyle,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _save(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
    required this.initials,
    required this.onTap,
    this.imageUrl,
    this.pickedBytes,
    this.enabled = true,
  });

  final String initials;
  final String? imageUrl;
  final Uint8List? pickedBytes;
  final VoidCallback onTap;
  final bool enabled;

  static const _size = 96.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (pickedBytes != null)
              ClipOval(
                child: Image.memory(
                  pickedBytes!,
                  width: _size,
                  height: _size,
                  fit: BoxFit.cover,
                ),
              )
            else
              ProfileAvatar(
                initials: initials,
                imageUrl: imageUrl,
                size: _size,
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: TaskerColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: const AppHugeIcon(
                  icon: HugeIcons.strokeRoundedEdit01,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

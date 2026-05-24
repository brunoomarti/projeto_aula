import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_card_style.dart';
import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/layout/tasker_breakpoints.dart';
import '../../../../core/services/user_local_service.dart';
import '../../../tasks/presentation/widgets/complete_input.dart';
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

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
    await UserLocalService.setDisplayName(_nameController.text);
    widget.onNameSaved?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nome salvo no dispositivo.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final pagePadding = TaskerBreakpoints.pagePadding(width);
          final isWide = TaskerBreakpoints.isWide(width);

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              pagePadding.left,
              16,
              pagePadding.right,
              pagePadding.bottom,
            ),
            child: TaskerResponsiveContent(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Meu perfil',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: TaskerColors.primaryText,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Seu nome aparece no topo da tela inicial.',
                    style: TextStyle(color: TaskerColors.secondaryText),
                  ),
                  const SizedBox(height: TaskerCardStyle.sectionSpacing),
                  TaskSectionCard(
                    title: 'Identificação',
                    icon: Icons.person_outline,
                    child: CompleteInput(
                      label: 'Nome',
                      child: TextField(
                        controller: _nameController,
                        decoration: TaskerFieldDecoration.decoration(
                          hintText: 'Como devemos te chamar?',
                        ),
                        style: TaskerFieldDecoration.textStyle,
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                  ),
                  const SizedBox(height: TaskerCardStyle.sectionSpacing),
                  if (isWide)
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 200,
                        child: _SaveButton(onPressed: _save),
                      ),
                    )
                  else
                    _SaveButton(onPressed: _save),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: TaskerColors.primary,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        'Salvar',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

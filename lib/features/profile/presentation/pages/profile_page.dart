import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../../core/services/user_local_service.dart';
import '../../../tasks/presentation/widgets/complete_input.dart';

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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Perfil',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: TaskerColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Seu nome aparece no topo da tela inicial.',
              style: TextStyle(color: TaskerColors.secondaryText),
            ),
            const SizedBox(height: 24),
            CompleteInput(
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
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: TaskerColors.primary,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

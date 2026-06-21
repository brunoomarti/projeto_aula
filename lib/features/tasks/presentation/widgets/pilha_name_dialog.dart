import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';

/// Modal para nomear uma pilha criada por arrastar tarefas na home.
///
/// Retorna o nome confirmado ou `null` se o usuário cancelar.
Future<String?> showPilhaNameDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => const _PilhaNameDialog(),
  );
}

class _PilhaNameDialog extends StatefulWidget {
  const _PilhaNameDialog();

  @override
  State<_PilhaNameDialog> createState() => _PilhaNameDialogState();
}

class _PilhaNameDialogState extends State<_PilhaNameDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Informe um nome para a pilha.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova pilha'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Arraste tarefas para agrupá-las. Como quer chamar esta pilha?',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Nome da pilha',
              hintText: 'Ex.: Compras da semana',
              errorText: _errorText,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: TextStyle(color: TaskerColors.secondaryText),
          ),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: TaskerColors.primary,
          ),
          child: const Text('Criar pilha'),
        ),
      ],
    );
  }
}

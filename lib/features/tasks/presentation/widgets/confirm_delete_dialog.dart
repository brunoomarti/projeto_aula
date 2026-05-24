import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';

/// Modal de confirmação — equivalente ao ConfirmDeleteModal da referência.
class ConfirmDeleteDialog extends StatefulWidget {
  const ConfirmDeleteDialog({
    super.key,
    required this.open,
    required this.taskTitle,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool open;
  final String? taskTitle;
  final VoidCallback onCancel;
  final Future<void> Function() onConfirm;

  @override
  State<ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<ConfirmDeleteDialog>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.02),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant ConfirmDeleteDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !oldWidget.open) {
      _controller.forward(from: 0);
    } else if (!widget.open && oldWidget.open) {
      _controller.reverse();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.open) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onConfirm();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open && _controller.isDismissed) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.isDismissed) return const SizedBox.shrink();

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _loading ? null : widget.onCancel,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.25 * _fade.value),
                ),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Material(
                    color: Colors.white,
                    elevation: 8,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Excluir tarefa?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: TaskerColors.primaryText,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text.rich(
                              TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: TaskerColors.secondaryText,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Tem certeza que deseja excluir ',
                                  ),
                                  TextSpan(
                                    text: widget.taskTitle ?? 'esta tarefa',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: TaskerColors.primaryText,
                                    ),
                                  ),
                                  const TextSpan(text: '?'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed:
                                      _loading ? null : widget.onCancel,
                                  child: const Text('Cancelar'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFE15E5B),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed:
                                      _loading ? null : _handleConfirm,
                                  child: _loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Excluir'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

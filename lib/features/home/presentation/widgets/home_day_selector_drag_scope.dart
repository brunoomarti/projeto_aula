import 'package:flutter/material.dart';

/// Delegação de arrasto para o seletor de dias (registrada por [HomeDaySelector]).
typedef HomeDaySelectorDragDelegate = ({
  bool Function(Offset globalPosition) handleDragPosition,
  void Function() stopAutoScroll,
  void Function() onDragEnded,
});

/// Ponte entre [TaskDragWrapper] e o estado interno do [HomeDaySelector].
class HomeDaySelectorDragController {
  HomeDaySelectorDragDelegate? _delegate;
  bool isDragOverSelector = false;

  void attach(HomeDaySelectorDragDelegate delegate) {
    _delegate = delegate;
  }

  void detach() {
    _delegate = null;
    isDragOverSelector = false;
  }

  void handleDragPosition(Offset globalPosition) {
    isDragOverSelector =
        _delegate?.handleDragPosition(globalPosition) ?? false;
  }

  void stopAutoScroll() {
    _delegate?.stopAutoScroll();
  }

  void onDragEnded() {
    isDragOverSelector = false;
    _delegate?.onDragEnded();
  }
}

/// Expõe [HomeDaySelectorDragController] para widgets descendentes (lista de tarefas).
class HomeDaySelectorDragScope extends InheritedWidget {
  const HomeDaySelectorDragScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final HomeDaySelectorDragController controller;

  static HomeDaySelectorDragController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HomeDaySelectorDragScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(covariant HomeDaySelectorDragScope oldWidget) {
    return oldWidget.controller != controller;
  }
}

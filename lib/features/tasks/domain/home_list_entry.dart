import 'package:flutter/foundation.dart';

import 'pilha.dart';
import 'task.dart';

/// Item da lista da home — tarefa avulsa ou pilha agrupada.
@immutable
sealed class HomeListEntry {
  const HomeListEntry();
}

@immutable
class HomeSingleTaskEntry extends HomeListEntry {
  const HomeSingleTaskEntry(this.task);

  final Task task;
}

@immutable
class HomePilhaEntry extends HomeListEntry {
  const HomePilhaEntry({required this.pilha, required this.tasks});

  final Pilha pilha;
  final List<Task> tasks;
}

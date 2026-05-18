import 'package:flutter/material.dart';

import '../../../../app/theme/tasker_colors.dart';
import '../../../tasks/data/task_local_repository.dart';
import '../../../tasks/domain/task.dart';

/// Tarefas concluídas — equivalente a [tasker-main/src/dashboard.jsx] (somente local).
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  List<Task> _completed = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final tasks = await TaskLocalRepository.instance.getCompleted();
    tasks.sort((a, b) => b.hora.compareTo(a.hora));
    if (!mounted) return;
    setState(() {
      _completed = tasks;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tarefas concluídas',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: TaskerColors.primaryText,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _completed.isEmpty
                      ? const Text(
                          'Nenhuma tarefa concluída.',
                          style: TextStyle(color: TaskerColors.secondaryText),
                        )
                      : ListView.separated(
                          itemCount: _completed.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final task = _completed[index];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: TaskerColors.cardBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: TaskerColors.cardBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: TaskerColors.cardShadow,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: TaskerColors.primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.schedule,
                                            size: 18,
                                            color: TaskerColors.secondaryText,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            task.hora.isEmpty
                                                ? '—'
                                                : task.hora,
                                            style: const TextStyle(
                                              color: TaskerColors.secondaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Text(
                                        'Concluída',
                                        style: TextStyle(
                                          color: TaskerColors.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

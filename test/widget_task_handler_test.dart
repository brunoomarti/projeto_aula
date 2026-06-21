import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tasker_project/core/services/magic_task_builder.dart';
import 'package:tasker_project/core/services/widget_task_handler.dart';
import 'package:tasker_project/features/tasks/data/task_local_repository.dart';
import 'package:tasker_project/features/tasks/domain/task.dart';
import 'package:tasker_project/features/tasks/presentation/state/task_store.dart';

void main() {
  setUpAll(() {
    dotenv.loadFromString(
      envString: '''
GEMINI_API_KEY=
GOOGLE_PLACES_API_KEY=
SUPABASE_URL=
SUPABASE_ANON_KEY=
''',
      isOptional: true,
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('WidgetTaskHandler.createTaskFromText', () {
    test('interpreta dentista amanhã 14h', () async {
      final ref = DateTime(2026, 6, 15, 12);
      final task = await MagicTaskBuilder.buildFromText(
        text: 'dentista amanhã 14h',
        referenceDate: ref,
        resolveLocation: false,
      );

      expect(task.title.toLowerCase(), contains('dentista'));
      expect(task.hora, '14:00');
      expect(task.data, '2026-06-16');
      expect(task.location, isNull);
    });

    test('modo widget não tenta geocoding mesmo com lugar na frase', () async {
      final task = await WidgetTaskHandler.createTaskFromText(
        'reunião na faculdade amanhã 10h',
      );

      expect(task.title.toLowerCase(), contains('reuni'));
      expect(task.location, isNull);
    });

    test('lista de compras sem local usa titulo generico', () async {
      final task = await WidgetTaskHandler.createTaskFromText(
        'comprar arroz feijao e macarrao',
      );

      expect(task.title.toLowerCase(), contains('compras'));
      expect(task.descricao.toLowerCase(), contains('arroz'));
      expect(task.descricao.toLowerCase(), contains('feij'));
      expect(task.descricao.toLowerCase(), contains('macarr'));
    });

    test('produto unico nao vira lista de afazeres', () async {
      final task = await WidgetTaskHandler.createTaskFromText(
        'comprar camisa do brasil amanha',
      );

      expect(task.title.toLowerCase(), contains('camisa'));
      expect(task.title.toLowerCase(), contains('brasil'));
      expect(task.descricao.trim(), isEmpty);
      expect(task.data, isNotEmpty);
    });
  });

  group('WidgetTaskHandler.formatTaskSummary', () {
    test('inclui título, data relativa e hora', () {
      final task = Task(
        id: '1',
        title: 'Dentista',
        data: TaskStore.formatDateYmd(
          DateTime.now().add(const Duration(days: 1)),
        ),
        hora: '14:00',
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      final summary = WidgetTaskHandler.formatTaskSummary(task);

      expect(summary, contains('Dentista'));
      expect(summary, contains('amanhã'));
      expect(summary, contains('14:00'));
    });

    test('inclui nome do local quando presente', () {
      final task = Task(
        id: '2',
        title: 'Reunião',
        data: TaskStore.formatDateYmd(DateTime.now()),
        hora: '09:00',
        location: const TaskLocation(lat: -19.5, lng: -40.6, name: 'Sapion'),
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      final summary = WidgetTaskHandler.formatTaskSummary(task);

      expect(summary, contains('Sapion'));
      expect(summary, contains('hoje'));
    });
  });

  group('WidgetTaskHandler persistência local', () {
    test('salva tarefa do widget como pendente de sync', () async {
      final task = await WidgetTaskHandler.createTaskFromText(
        'comprar leite hoje 18h',
      );

      final pending = task.copyWith(synced: false);
      await TaskLocalRepository.instance.addTask(pending);

      final all = await TaskLocalRepository.instance.getAll();
      expect(all, hasLength(1));
      expect(all.first.title.toLowerCase(), contains('leite'));
      expect(all.first.synced, isFalse);
    });
  });

  group('WidgetTaskHandler.handleBackgroundUri', () {
    test('ignora URIs que não são createTask', () async {
      await WidgetTaskHandler.handleBackgroundUri(
        Uri.parse('taskerWidget://other'),
      );
      // Sem exceção e sem efeitos colaterais observáveis.
    });
  });
}

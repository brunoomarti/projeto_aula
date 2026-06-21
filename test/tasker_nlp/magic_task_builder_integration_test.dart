import 'package:flutter_test/flutter_test.dart';
import 'package:tasker_project/core/services/magic_task_builder.dart';

/// Integração app ↔ package `tasker_nlp` via [MagicTaskBuilder.buildFromText].
void main() {
  final ref = DateTime(2026, 5, 24, 12, 0);

  group('MagicTaskBuilder + tasker_nlp (NLP local)', () {
    test('extrai data, hora, título e ícone de reunião', () async {
      final task = await MagicTaskBuilder.buildFromText(
        text: 'Reunião com Ana quinta às 14h',
        referenceDate: ref,
        useGemini: false,
        resolveLocation: false,
      );

      expect(task.title.toLowerCase(), contains('reuni'));
      expect(task.hora, '14:00');
      expect(task.data, isNotEmpty);
      expect(task.iconKey, 'work');
    });

    test('extrai veterinário, amanhã e ícone pets', () async {
      final task = await MagicTaskBuilder.buildFromText(
        text: 'Levar meu pet ao veterinário amanhã',
        referenceDate: ref,
        useGemini: false,
        resolveLocation: false,
      );

      expect(task.title.toLowerCase(), anyOf(contains('pet'), contains('veterin')));
      expect(task.data, '2026-05-25');
      expect(task.iconKey, 'pets');
    });

    test('extrai horário coloquial e limpa título', () async {
      final task = await MagicTaskBuilder.buildFromText(
        text: 'dentista 2 e meia da tarde',
        referenceDate: ref,
        useGemini: false,
        resolveLocation: false,
      );

      expect(task.hora, '14:30');
      expect(task.title.toLowerCase(), 'Dentista'.toLowerCase());
    });

    test('extrai academia e ícone gym', () async {
      final task = await MagicTaskBuilder.buildFromText(
        text: 'Ir à academia às 07:30',
        referenceDate: ref,
        useGemini: false,
        resolveLocation: false,
      );

      expect(task.hora, '07:30');
      expect(task.iconKey, 'gym');
    });

    test('enriquece título com destino quando há local nomeado', () async {
      final task = await MagicTaskBuilder.buildFromText(
        text: 'levar gata no ama hospital vetrinario as 14h',
        referenceDate: ref,
        useGemini: false,
        resolveLocation: false,
      );

      expect(task.title.toLowerCase(), contains('veterin'));
      expect(task.hora, '14:00');
      expect(task.iconKey, anyOf('pets', 'health'));
      expect(task.location, isNull);
    });

    test('comprar pao na digrano no inicio da noite', () async {
      final task = await MagicTaskBuilder.buildFromText(
        text: 'comprar pao na digrano no inicio da noite',
        useGemini: false,
        resolveLocation: false,
      );

      expect(task.hora, '18:00');
      expect(task.title.toLowerCase(), contains('comprar'));
      expect(task.title.toLowerCase(), contains('pao'));
      expect(task.title.toLowerCase(), isNot(contains('digrano')));
      expect(task.title.toLowerCase(), isNot(contains('inicio')));
    });

    test('supermercado de tarde mantém 15:00', () async {
      final task = await MagicTaskBuilder.buildFromText(
        text: 'ir no supermercado de tarde comprar mamão banana e açúcar',
        referenceDate: ref,
        useGemini: false,
        resolveLocation: false,
      );

      expect(task.hora, '15:00');
      expect(task.title.toLowerCase(), contains('supermercado'));
    });
  });
}

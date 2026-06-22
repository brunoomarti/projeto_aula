import 'package:flutter_test/flutter_test.dart';
import 'package:tasker_project/core/services/magic_task_builder.dart';

void main() {
  test('magic input local: compras sem local geram lista de compras', () async {
    const text = 'comprar feijao arroz e macarrao amanha';

    final task = await MagicTaskBuilder.buildFromText(
      text: text,
      useGemini: false,
      resolveLocation: false,
    );

    expect(task.title, 'Lista de compras');
    expect(task.descricao, contains('Feijao'));
    expect(task.descricao, contains('Arroz'));
    expect(task.descricao, contains('Macarrao'));
    expect(task.data, isNotEmpty);
  });

  test('ordem arroz feijao e macarrao', () async {
    final task = await MagicTaskBuilder.buildFromText(
      text: 'comprar arroz feijao e macarrao',
      useGemini: false,
      resolveLocation: false,
    );

    expect(task.title, 'Lista de compras');
    expect(task.descricao.toLowerCase(), contains('arroz'));
    expect(task.descricao.toLowerCase(), contains('feijao'));
    expect(task.descricao.toLowerCase(), contains('macarrao'));
  });

  test('produto unico com do nao vira lista de compras', () async {
    final task = await MagicTaskBuilder.buildFromText(
      text: 'comprar camisa do brasil amanha',
      useGemini: false,
      resolveLocation: false,
      referenceDate: DateTime(2026, 6, 15),
    );

    expect(task.title.toLowerCase(), contains('camisa'));
    expect(task.title.toLowerCase(), contains('brasil'));
    expect(task.descricao.trim(), isEmpty);
    expect(task.data, '2026-06-16');
  });

  test('produto com adjetivo de cor nao vira lista', () async {
    final task = await MagicTaskBuilder.buildFromText(
      text: 'comprar um tenis branco',
      useGemini: false,
      resolveLocation: false,
    );

    expect(task.title.toLowerCase(), contains('tenis'));
    expect(task.title.toLowerCase(), contains('branco'));
    expect(task.descricao.trim(), isEmpty);
  });

  test('ir na rua comprar nao geocodifica rua', () async {
    final task = await MagicTaskBuilder.buildFromText(
      text: 'ir na rua comprar um tenis branco',
      useGemini: false,
      resolveLocation: false,
    );

    expect(task.location, isNull);
    // "rua" é stopword de lugar, não vira geocoding; título vem da ação principal.
    expect(task.title.toLowerCase(), isNot(contains('rua')));
    expect(task.descricao.trim(), isEmpty);
  });
}

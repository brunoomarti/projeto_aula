import 'package:flutter_test/flutter_test.dart';
import 'package:tasker_project/core/nlp/infer_task_icon_pt_br.dart';

void main() {
  group('inferTaskIconPTBR', () {
    test('supermercado → mercado', () {
      final r = inferTaskIconPTBR('Fazer mercado sábado de tarde');
      expect(r.iconKey, 'market');
    });

    test('cortar cabelo → beleza', () {
      final r = inferTaskIconPTBR('cortar meu cabelo hoje ao meio dia');
      expect(r.iconKey, 'beauty');
    });

    test('veterinário → pets', () {
      final r = inferTaskIconPTBR('Levar meu pet ao veterinário amanhã');
      expect(r.iconKey, 'pets');
    });

    test('reunião → trabalho', () {
      final r = inferTaskIconPTBR('Reunião com Ana quinta às 14h');
      expect(r.iconKey, 'work');
    });

    test('academia → gym', () {
      final r = inferTaskIconPTBR('Ir à academia às 07:30');
      expect(r.iconKey, 'gym');
    });

    test('texto genérico → task', () {
      final r = inferTaskIconPTBR('Terminar aquela coisa importante');
      expect(r.iconKey, kGenericTaskIconKey);
    });

    test('lavanderia → roupa', () {
      final r = inferTaskIconPTBR('Pegar roupas na lavanderia amanhã às 17h');
      expect(r.iconKey, 'clothing');
    });

    test('shopping → sacola de compras', () {
      final r = inferTaskIconPTBR('ir ao shopping vitoria 18h');
      expect(r.iconKey, 'shopping');
    });

    test('supermercado continua mercado', () {
      final r = inferTaskIconPTBR('compras no supermercado amanhã');
      expect(r.iconKey, 'market');
    });

    test('atribui cor válida do catálogo', () {
      final r = inferTaskIconPTBR('Comprar passagens até quarta');
      expect(r.iconKey, 'travel');
      expect(r.backgroundArgb, isNotNull);
    });

    test('culto na igreja → fé', () {
      final r = inferTaskIconPTBR('culto na igreja domingo às 19h');
      expect(r.iconKey, 'faith');
    });

    test('estudo bíblico → fé', () {
      final r = inferTaskIconPTBR('estudo bíblico quinta à noite');
      expect(r.iconKey, 'faith');
    });

    test('oração → fé', () {
      final r = inferTaskIconPTBR('oração e jejum amanhã cedo');
      expect(r.iconKey, 'faith');
    });
  });
}

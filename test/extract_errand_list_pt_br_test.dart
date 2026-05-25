import 'package:flutter_test/flutter_test.dart';
import 'package:tasker_project/core/nlp/extract_errand_list_pt_br.dart';
import 'package:tasker_project/core/nlp/extract_place_pt_br.dart';
import 'package:tasker_project/core/nlp/extract_when_pt_br.dart';

void main() {
  group('parseErrandListFromDescription', () {
    test('lê itens com marcador •', () {
      final items = parseErrandListFromDescription('• Banana\n• Maca\n• Mamao');
      expect(items, ['Banana', 'Maca', 'Mamao']);
      expect(isErrandListDescription('• Banana\n• Maca'), isTrue);
    });

    test('texto livre não é lista', () {
      expect(parseErrandListFromDescription('Comprar leite'), isEmpty);
      expect(isErrandListDescription('Notas gerais'), isFalse);
    });

    test('inline para home', () {
      expect(
        errandListInlineFromDescription('• Mamão\n• Banana\n• Açúcar'),
        'Mamão, Banana, Açúcar',
      );
    });
  });

  group('parseErrandItems', () {
    test('separa vírgulas e e', () {
      expect(parseErrandItems('banana, maça e mamao'), [
        'banana',
        'maça',
        'mamao',
      ]);
    });

    test('recupera lista após normPT remover vírgulas', () {
      expect(parseErrandItems('banana  maca e mamao'), [
        'banana',
        'maca',
        'mamao',
      ]);
    });

    test('expande palavras soltas sem vírgula', () {
      expect(parseErrandItems('mamao banana e acucar'), [
        'mamao',
        'banana',
        'acucar',
      ]);
    });
  });

  group('parseActionErrandItems', () {
    test('separa acoes por virgula', () {
      expect(
        parseActionErrandItems(
          'pagar uma conta no mercadao, comprar linhaca, buscar um condicional na musa',
        ),
        [
          'Pagar uma conta no mercadao',
          'Comprar linhaca',
          'Buscar um condicional na musa',
        ],
      );
    });

    test('separa acoes ligadas por e', () {
      expect(parseActionErrandItems('pagar conta e comprar linhaca'), [
        'Pagar conta',
        'Comprar linhaca',
      ]);
    });
  });

  group('extractErrandListPTBR', () {
    test('supermercado de tarde com frutas', () {
      const text = 'ir no supermercado de tarde comprar mamão banana e açúcar';
      final place = extractPlacePTBR(text);
      final errand = extractErrandListPTBR(text, place: place);
      final when = extractWhenPTBR(text);

      expect(place, isNotNull);
      expect(place!.searchQuery.toLowerCase(), 'supermercado');
      expect(place.skipGeocoding, isTrue);
      expect(place.searchQuery.toLowerCase(), isNot(contains(' de')));
      expect(place.matchedText.toLowerCase(), 'no supermercado');

      expect(errand, isNotNull);
      expect(errand!.items.length, 3);
      expect(errand.items[0].toLowerCase(), contains('mam'));
      expect(errand.items[1].toLowerCase(), 'banana');
      expect(
        errand.items[2].toLowerCase(),
        anyOf(contains('aç'), contains('acucar')),
      );

      expect(when.timeHHMM, '15:00');

      final title = errandTitleForPlace(place.searchQuery, errand.verb);
      expect(title, 'Comprar no Supermercado');
    });

    test('supermercado comprar frutas sem de tarde', () {
      const text = 'ir no supermercado comprar mamao banana e maca';
      final place = extractPlacePTBR(text);
      final errand = extractErrandListPTBR(text, place: place);

      expect(place, isNotNull);
      expect(place!.searchQuery.toLowerCase(), 'supermercado');
      expect(place.matchedText.toLowerCase(), 'no supermercado');
      expect(errand, isNotNull);
      expect(
        errandTitleForPlace(place.searchQuery, errand!.verb),
        'Comprar no Supermercado',
      );
    });

    test('lavagnoli com frutas e horário', () {
      const text = 'ir no lavangnoli comprar banana, maça e mamao de tarde';
      final place = extractPlacePTBR(text);
      final errand = extractErrandListPTBR(text, place: place);
      final when = extractWhenPTBR(text);

      expect(place, isNotNull);
      expect(place!.searchQuery.toLowerCase(), contains('lavangnoli'));

      expect(errand, isNotNull);
      expect(errand!.items.length, 3);
      expect(errand.description, contains('Banana'));
      expect(errand.description.toLowerCase(), contains('maça'));
      expect(errand.description, contains('Mamao'));
      expect(errand.verb, 'comprar');

      expect(when.timeHHMM, '15:00');

      final title = errandTitleForPlace(place.searchQuery, errand.verb);
      expect(title.toLowerCase(), contains('lavangnoli'));
      expect(title.toLowerCase(), contains('comprar'));
    });

    test('mercado nomeado com lista', () {
      const text =
          'comprar arroz, feijão e óleo no mercado Atacadão hoje à tarde';
      final place = extractPlacePTBR(text);
      final errand = extractErrandListPTBR(text, place: place);

      expect(place, isNotNull);
      expect(errand, isNotNull);
      expect(errand!.items.length, greaterThanOrEqualTo(2));
    });

    test('exige dois itens sem local', () {
      expect(extractErrandListPTBR('comprar leite amanhã'), isNull);
      final list = extractErrandListPTBR('comprar pão e café amanhã');
      expect(list, isNotNull);
      expect(list!.items.length, 2);
    });

    test('um item com local', () {
      const text = 'pegar remédio na farmácia Central hoje';
      final place = extractPlacePTBR(text);
      final errand = extractErrandListPTBR(text, place: place);
      expect(place, isNotNull);
      expect(errand, isNotNull);
      expect(errand!.items.any((i) => normPT(i).contains('remedio')), isTrue);
    });

    test('stripErrandFromTitle remove itens', () {
      const text = 'ir no Sesc comprar ingresso e pipoca de noite';
      final errand = extractErrandListPTBR(text)!;
      final cleaned = stripErrandFromTitle(text, errand);
      expect(cleaned.toLowerCase(), isNot(contains('ingresso')));
      expect(cleaned.toLowerCase(), isNot(contains('pipoca')));
    });

    test('lista de acoes na rua', () {
      const text =
          'preciso ir na rua para pagar uma conta no mercadao, comprar linhaca, buscar um condicional na musa';
      final errand = extractErrandListPTBR(text);

      expect(errand, isNotNull);
      expect(errand!.isActionList, isTrue);
      expect(errand.items.length, 3);
      expect(errand.parentTitle, 'Ir na rua');
      expect(errand.items[0].toLowerCase(), contains('pagar'));
      expect(errand.items[1].toLowerCase(), contains('linh'));
      expect(errand.items[2].toLowerCase(), contains('buscar'));

      final title = resolveErrandDisplayTitle(
        primaryTitle: 'Ir na rua',
        errand: errand,
        errandItems: errand.items,
      );
      expect(title, 'Ir na rua');
    });
  });
}

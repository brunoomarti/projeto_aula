import 'package:test/test.dart';
import 'package:tasker_nlp/tasker_nlp.dart';

void main() {
  group('extractPlacePTBR', () {
    test('IFES com horário', () {
      final p = extractPlacePTBR('faculdade no IFES hoje às 19 horas');
      expect(p, isNotNull);
      expect(p!.searchQuery.toUpperCase(), contains('IFES'));
      expect(p.matchedText.toLowerCase(), contains('ifes'));
    });

    test('aula no ifes às 7 horas da noite', () {
      final p = extractPlacePTBR('aula no ifes hoje às 7 horas da noite');
      expect(p, isNotNull);
      expect(p!.searchQuery.toUpperCase(), contains('IFES'));
    });

    test('IFES campus Colatina', () {
      final p = extractPlacePTBR('aula no IFES campus Colatina hoje');
      expect(p, isNotNull);
      expect(p!.searchQuery.toUpperCase(), contains('IFES'));
      expect(
        p.qualifiers.any((q) => q.toLowerCase().contains('colatina')),
        isTrue,
      );
    });

    test('ignora mercado genérico', () {
      expect(extractPlacePTBR('fazer mercado hoje à tarde'), isNull);
      expect(extractPlacePTBR('ir no mercado amanhã'), isNull);
    });

    test('supermercado genérico com lista de compras', () {
      final p = extractPlacePTBR(
        'ir no supermercado de tarde comprar mamão banana e açúcar',
      );
      expect(p, isNotNull);
      expect(p!.searchQuery.toLowerCase(), 'supermercado');
      expect(p.matchedText.toLowerCase(), 'no supermercado');
      expect(p.skipGeocoding, isTrue);
    });

    test('mercado com nome próprio', () {
      final p = extractPlacePTBR('compras no mercado Atacadão hoje');
      expect(p, isNotNull);
      expect(p!.searchQuery.toLowerCase(), contains('atacad'));
    });

    test('endereço com rua', () {
      final p = extractPlacePTBR('entrega na Rua Sete de Setembro 100 amanhã');
      expect(p, isNotNull);
      expect(p!.searchQuery.toLowerCase(), contains('rua'));
    });

    test('ir na rua idiomático não vira local geocodificado', () {
      expect(
        extractPlacePTBR('ir na rua comprar um tenis branco'),
        isNull,
      );
      expect(
        extractPlacePTBR('preciso ir na rua para pagar conta'),
        isNull,
      );
      expect(isColloquialNonPlace('rua'), isTrue);
    });

    test('outras expressões coloquiais não viram local', () {
      expect(extractPlacePTBR('ir na cidade comprar um tenis'), isNull);
      expect(extractPlacePTBR('dar um rolê no centro'), isNull);
      expect(extractPlacePTBR('vou dar uma volta resolver umas coisas'), isNull);
      expect(isColloquialNonPlace('cidade'), isTrue);
      expect(isColloquialNonPlace('centro'), isTrue);
      expect(isColloquialNonPlace('role'), isTrue);
    });

    test('lugar real com nome próprio não é tratado como coloquial', () {
      expect(isColloquialNonPlace('centro de eventos'), isFalse);
      expect(isColloquialNonPlace('rua sete de setembro'), isFalse);
      final centro = extractPlacePTBR('reunião no Centro de Eventos amanhã');
      expect(centro, isNotNull);
    });

    test('stripPlaceFromTitle limpa título', () {
      final p = extractPlacePTBR('faculdade no IFES hoje às 19 horas')!;
      final parsed = extractWhenPTBR('faculdade no IFES hoje às 19 horas');
      final title = stripPlaceFromTitle(parsed.title, p);
      expect(title.toLowerCase(), isNot(contains('ifes')));
      expect(title.toLowerCase(), contains('faculdade'));
    });

    test('shopping com horário compacto', () {
      final p = extractPlacePTBR('ir ao shopping vitoria 18h');
      expect(p, isNotNull);
      expect(p!.searchQuery.toLowerCase(), contains('shopping'));
      expect(p.searchQuery.toLowerCase(), contains('vitoria'));
      expect(p.searchQuery.toLowerCase(), isNot(contains('18h')));
      expect(p.matchedText.toLowerCase(), isNot(contains('18h')));
      expect(
        p.qualifiers.any((q) => q.toLowerCase().contains('vitoria')),
        isTrue,
      );
    });

    test('dedupe de voz repetida', () {
      final p = extractPlacePTBR(
        'ir ao shopping vitoria ir ao shopping vitoria 18h',
      );
      expect(p, isNotNull);
      expect(p!.searchQuery.toLowerCase(), 'shopping vitoria');
    });

    test('IFES não inclui horário no matchedText', () {
      final p = extractPlacePTBR('aula no ifes hoje às 19 horas');
      expect(p, isNotNull);
      expect(p!.matchedText.toLowerCase(), isNot(contains('19')));
      expect(p.matchedText.toLowerCase(), isNot(contains('hoje')));
    });
  });

  group('place display and title enrichment', () {
    test('formatPlaceDisplayName remove preposição', () {
      final p = extractPlacePTBR(
        'levar gata no ama hospital vetrinario as 14h',
      )!;
      expect(
        formatPlaceDisplayName(p).toLowerCase(),
        contains('ama'),
      );
      expect(
        formatPlaceDisplayName(p).toLowerCase(),
        contains('hospital'),
      );
    });

    test('enrichTitleWithPlaceDestination adiciona veterinário', () {
      final p = extractPlacePTBR(
        'levar gata no ama hospital vetrinario as 14h',
      )!;
      final enriched = enrichTitleWithPlaceDestination(
        title: 'Levar gata',
        placeQuery: p.searchQuery,
      );
      expect(enriched.toLowerCase(), contains('veterin'));
    });

    test('enrichTitleWithTranscriptContext entende detran e carteira', () {
      final enriched = enrichTitleWithTranscriptContext(
        title: 'Carteira',
        transcript: 'ir no detran renovar a carteira',
        placeQuery: 'Detran',
      );
      expect(enriched.toLowerCase(), contains('renovar'));
      expect(enriched.toLowerCase(), contains('motorista'));
    });
  });
}

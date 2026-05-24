import 'package:flutter_test/flutter_test.dart';
import 'package:tasker_project/core/nlp/extract_place_pt_br.dart';
import 'package:tasker_project/core/nlp/extract_when_pt_br.dart';
import 'package:tasker_project/features/tasks/domain/address_suggestion.dart';
import 'package:tasker_project/features/tasks/domain/task.dart';
import 'package:tasker_project/core/nlp/resolve_place_location.dart';

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

  group('pickBestPlaceSuggestion', () {
    final nearColatina = TaskLocation(lat: -19.539, lng: -40.630);
    final nearItapina = TaskLocation(lat: -20.385, lng: -40.308);

    AddressSuggestion ifesColatina() => AddressSuggestion(
          displayName: 'IFES Campus Colatina, Colatina, ES',
          shortLabel: 'IFES · Colatina',
          location: TaskLocation(lat: -19.5392, lng: -40.6308),
          categoryLabel: 'Universidade',
        );

    AddressSuggestion ifesItapina() => AddressSuggestion(
          displayName: 'IFES Campus Itapina, Colatina, ES',
          shortLabel: 'IFES · Itapina',
          location: TaskLocation(lat: -20.385, lng: -40.308),
          categoryLabel: 'Universidade',
        );

    test('sem campus escolhe o mais próximo', () {
      final place = ExtractPlaceResult(
        searchQuery: 'IFES',
        matchedText: 'no IFES',
      );
      final best = pickBestPlaceSuggestion(
        [ifesItapina(), ifesColatina()],
        place,
        nearColatina,
      );
      expect(best?.shortLabel, contains('Colatina'));
    });

    test('campus explícito prioriza qualificador', () {
      final place = ExtractPlaceResult(
        searchQuery: 'IFES Itapina',
        matchedText: 'no IFES campus Itapina',
        qualifiers: ['itapina'],
      );
      final best = pickBestPlaceSuggestion(
        [ifesColatina(), ifesItapina()],
        place,
        nearColatina,
      );
      expect(best?.shortLabel.toLowerCase(), contains('itapina'));
    });
  });
}

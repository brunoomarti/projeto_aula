import 'package:flutter_test/flutter_test.dart';
import 'package:tasker_project/core/services/transcript_accumulator.dart';

void main() {
  group('TranscriptAccumulator', () {
    test('preserva texto anterior quando ASR reinicia o segmento', () {
      final acc = TranscriptAccumulator();

      acc.apply('comprar leite e pao');
      acc.apply('farinha');

      expect(acc.text, 'comprar leite e pao farinha');
    });

    test('atualiza parcial dentro do mesmo segmento', () {
      final acc = TranscriptAccumulator();

      acc.apply('comprar lei');
      acc.apply('comprar leite');

      expect(acc.text, 'comprar leite');
    });

    test('finaliza segmento e continua no próximo', () {
      final acc = TranscriptAccumulator();

      acc.apply('comprar leite', isFinal: true);
      acc.apply('e pao');

      expect(acc.text, 'comprar leite e pao');
    });

    test('flush commita parcial pendente', () {
      final acc = TranscriptAccumulator();

      acc.apply('ir ao mercado');
      acc.flush();
      acc.apply('comprar arroz');

      expect(acc.text, 'ir ao mercado comprar arroz');
    });

    test('não duplica trecho final repetido', () {
      final acc = TranscriptAccumulator();

      acc.apply('comprar leite e pão', isFinal: true);
      acc.apply('comprar leite e pão', isFinal: true);

      expect(acc.text, 'comprar leite e pão');
    });

    test('parcial cumulativo não duplica ao crescer', () {
      final acc = TranscriptAccumulator();

      acc.apply('comprar leite');
      acc.apply('comprar leite e pão');
      acc.apply('comprar leite e pão', isFinal: true);

      expect(acc.text, 'comprar leite e pão');
    });
  });
}

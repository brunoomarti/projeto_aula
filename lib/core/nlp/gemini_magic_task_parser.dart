import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/env_config.dart';
import '../config/magic_input_parser_config.dart';
import '../../features/tasks/domain/task_icon_catalog.dart';
import '../../features/tasks/presentation/state/task_store.dart';
import 'extract_errand_list_pt_br.dart';
import 'extract_place_pt_br.dart';
import 'extract_when_pt_br.dart';

/// Resultado estruturado do Gemini para montar uma [Task] no magic input.
class GeminiMagicTaskParseResult {
  const GeminiMagicTaskParseResult({
    required this.title,
    this.dateYmd,
    this.timeHHMM,
    this.placeSearchQuery,
    this.placeSkipGeocoding = false,
    this.errandItems = const [],
    this.iconKey,
  });

  final String title;
  final String? dateYmd;
  final String? timeHHMM;
  final String? placeSearchQuery;
  final bool placeSkipGeocoding;
  final List<String> errandItems;
  final String? iconKey;
}

/// Parser híbrido via Gemini — complementa o NLP local sem substituí-lo.
abstract final class GeminiMagicTaskParser {
  GeminiMagicTaskParser._();

  static const _timeout = Duration(seconds: 18);

  static const _validIconKeys = {
    'home',
    'gym',
    'market',
    'shopping',
    'food',
    'people',
    'tree',
    'walk',
    'work',
    'study',
    'health',
    'pets',
    'travel',
    'event',
    'repair',
    'clothing',
    'beauty',
    'faith',
    'task',
  };

  /// Interpreta o transcript e devolve campos da tarefa.
  ///
  /// Lança [GeminiMagicTaskParserException] se a API falhar ou o JSON for inválido.
  static Future<GeminiMagicTaskParseResult> parseTaskFromText({
    required String transcript,
    required DateTime referenceDate,
  }) async {
    if (!EnvConfig.isGeminiConfigured) {
      throw GeminiMagicTaskParserException('GEMINI_API_KEY não configurada.');
    }

    final refYmd = TaskStore.formatDateYmd(TaskStore.dateOnly(referenceDate));
    final prompt = _buildPrompt(transcript.trim(), refYmd);

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '${MagicInputParserConfig.geminiModel}:generateContent'
      '?key=${Uri.encodeComponent(EnvConfig.geminiApiKey)}',
    );

    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0,
              'responseMimeType': 'application/json',
            },
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw GeminiMagicTaskParserException(
        'Gemini HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final rawText = _extractTextFromGeminiResponse(response.body);
    final map = decodeGeminiTaskJson(rawText);

    if (kDebugMode) {
      debugPrint('GeminiMagicTaskParser JSON: $map');
    }

    final gemini = _mapToResult(map, fallbackReferenceYmd: refYmd);
    return refineWithLocalSignals(
      gemini: gemini,
      transcript: transcript.trim(),
      referenceDate: referenceDate,
    );
  }

  /// Cruza a resposta do Gemini com o NLP local (sem substituir o NLP do projeto).
  ///
  /// O Gemini interpreta a intenção; o NLP corrige padrões fixos de PT-BR (amanhã,
  /// «duas da tarde», dia explícito) quando o modelo erra.
  static GeminiMagicTaskParseResult refineWithLocalSignals({
    required GeminiMagicTaskParseResult gemini,
    required String transcript,
    required DateTime referenceDate,
  }) {
    final ref = TaskStore.dateOnly(referenceDate);
    final when = extractWhenPTBR(transcript, ref);
    final place = extractPlacePTBR(transcript);
    final errand = extractErrandListPTBR(transcript, place: place);

    final colloquialTime = _inferColloquialTimePtBr(transcript);
    final timeHHMM = colloquialTime ?? when.timeHHMM ?? gemini.timeHHMM;

    final explicitDate = parseExplicitDate(transcript, ref)?.date;
    final relativeDate = parseRelativeDate(transcript, ref)?.date;
    final nlpDateYmd = when.dateYmd ??
        (explicitDate != null ? TaskStore.formatDateYmd(explicitDate) : null) ??
        (relativeDate != null
            ? TaskStore.formatDateYmd(relativeDate)
            : null);

    final dateYmd = nlpDateYmd ?? gemini.dateYmd;

    final placeSearchQuery =
        gemini.placeSearchQuery ?? place?.searchQuery;
    final placeSkipGeocoding =
        gemini.placeSkipGeocoding || (place?.skipGeocoding ?? false);

    final errandItems = gemini.errandItems.isNotEmpty
        ? gemini.errandItems
        : (errand?.items ?? const <String>[]);

    var title = gemini.title.trim();
    if (_titleLooksContaminated(title)) {
      final nlpTitle = when.title.trim();
      if (nlpTitle.isNotEmpty && !_titleLooksContaminated(nlpTitle)) {
        title = nlpTitle;
      } else {
        title = _titleFromTranscriptCore(
          transcript,
          place: place,
          errand: errand,
          hasTime: timeHHMM != null,
          hasDate: dateYmd != null,
        );
      }
    }
    title = _polishTitle(
      title: title,
      transcript: transcript,
      place: place,
      errand: errand,
      hasTime: timeHHMM != null,
      hasDate: dateYmd != null,
    );
    if (title.isEmpty) {
      title = when.title.trim().isNotEmpty
          ? when.title.trim()
          : transcript.trim();
    }

    return GeminiMagicTaskParseResult(
      title: title,
      dateYmd: dateYmd,
      timeHHMM: timeHHMM,
      placeSearchQuery: placeSearchQuery,
      placeSkipGeocoding: placeSkipGeocoding,
      errandItems: errandItems,
      iconKey: gemini.iconKey,
    );
  }

  @visibleForTesting
  static String? inferColloquialTimePtBr(String text) =>
      _inferColloquialTimePtBr(text);

  @visibleForTesting
  static Map<String, dynamic> decodeGeminiTaskJson(String rawText) {
    var text = rawText.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }

    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw GeminiMagicTaskParserException('Resposta Gemini não é um objeto JSON.');
    }
    return decoded;
  }

  static String _buildPrompt(String transcript, String referenceDateYmd) {
    return '''
Você interpreta o que o usuário QUIS DIZER em português do Brasil (texto ou voz/ASR).
Extraia uma tarefa e retorne SOMENTE JSON válido (sem markdown):
{
  "title": "string",
  "dateYmd": "YYYY-MM-DD ou null",
  "timeHHMM": "HH:mm ou null",
  "placeSearchQuery": "string ou null",
  "placeSkipGeocoding": false,
  "errandItems": [],
  "iconKey": "work|null"
}

REGRAS CRÍTICAS
- "title": só o núcleo da ação (ex.: "Reunião de negócios"). NUNCA coloque no title: hora, data, local, números de hora ("duas", "três"), "amanhã", "tarde", "manhã", nome de lugar.
- "dateYmd": converta expressões relativas para data ISO. "amanhã" = dia seguinte à referência. "dia 29" = dia 29 do mês (mês atual ou próximo). Se NÃO houver data na frase → null (não use a data de referência como dateYmd).
- Data de referência do calendário (só para calcular "hoje/amanhã/depois de amanhã"): $referenceDateYmd
- "timeHHMM": hora explícita em 24h. NÃO use 15:00 só porque apareceu "tarde" se houver hora por extenso.
- Horas por extenso (obrigatório):
  • "meio-dia" / "meio dia" → 12:00
  • "meia-noite" → 00:00
  • "uma da tarde" → 13:00, "duas da tarde" → 14:00, "três da tarde" → 15:00, "quatro da tarde" → 16:00
  • "uma da manhã" → 01:00 ou 07:00 conforme contexto; "sete da manhã" → 07:00, "oito da manhã" → 08:00
  • "duas e meia da tarde" → 14:30
  • "às 14h", "14:30", "14 horas" → formato HH:mm
- "placeSearchQuery": nome próprio do local para busca (ex.: "Sapion", "Sapion Nova Educação"). Sem "na/no/em". null se não houver local.
- "placeSkipGeocoding": true apenas para tipo genérico sem nome ("supermercado", "farmácia").
- "errandItems": itens de compras/lista quando houver; senão [].
- "iconKey": um de: home, gym, market, shopping, food, people, tree, walk, work, study, health, pets, travel, event, repair, clothing, beauty, faith, task — ou null.

EXEMPLOS (aprenda o padrão):
Entrada: "reunião de negócios na sapion amanhã duas da tarde"
Saída: {"title":"Reunião de negócios","dateYmd":"<amanhã ISO>","timeHHMM":"14:00","placeSearchQuery":"Sapion","placeSkipGeocoding":false,"errandItems":[],"iconKey":"work"}

Entrada: "comprar leite e pão no mercado amanhã"
Saída: {"title":"Compras no mercado","dateYmd":"<amanhã ISO>","timeHHMM":null,"placeSearchQuery":"mercado","placeSkipGeocoding":true,"errandItems":["leite","pão"],"iconKey":"market"}

Entrada: "dentista terça às 15h"
Saída: {"title":"Dentista","dateYmd":"<próxima terça ISO>","timeHHMM":"15:00","placeSearchQuery":null,"placeSkipGeocoding":false,"errandItems":[],"iconKey":"health"}

Texto do usuário (interprete a intenção mesmo se estiver mal escrito ou sem pontuação):
"$transcript"
''';
  }

  static String? _inferColloquialTimePtBr(String text) {
    final low = normPT(text);

    if (RegExp(r'\bmeio[\s-]?dia\b').hasMatch(low)) return '12:00';
    if (RegExp(r'\bmeia[\s-]?noite\b').hasMatch(low)) return '00:00';

    final afternoon = RegExp(
      r'\b(uma|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|onze|doze)'
      r'(?:\s+e\s+meia)?\s+da\s+tarde\b',
    ).firstMatch(low);
    if (afternoon != null) {
      final word = afternoon.group(1)!;
      final hour = _colloquialHourWordToInt(word);
      if (hour != null) {
        var hh = 12 + hour;
        if (hh > 23) hh = 23;
        var mm = 0;
        if (afternoon.group(0)!.contains('meia')) mm = 30;
        return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
      }
    }

    final morning = RegExp(
      r'\b(uma|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|onze|doze)'
      r'(?:\s+e\s+meia)?\s+da\s+manha\b',
    ).firstMatch(low);
    if (morning != null) {
      final word = morning.group(1)!;
      final hour = _colloquialHourWordToInt(word);
      if (hour != null) {
        var hh = hour;
        if (word == 'uma' && !morning.group(0)!.contains('meia')) {
          hh = 7;
        }
        var mm = 0;
        if (morning.group(0)!.contains('meia')) mm = 30;
        return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
      }
    }

    return null;
  }

  static int? _colloquialHourWordToInt(String word) {
    const map = {
      'uma': 1,
      'duas': 2,
      'tres': 3,
      'quatro': 4,
      'cinco': 5,
      'seis': 6,
      'sete': 7,
      'oito': 8,
      'nove': 9,
      'dez': 10,
      'onze': 11,
      'doze': 12,
    };
    return map[word];
  }

  static bool _titleLooksContaminated(String title) {
    final low = normPT(title);
    if (low.isEmpty) return true;
    return RegExp(
      r'\b(duas|tres|quatro|cinco|seis|sete|oito|nove|dez|onze|doze|uma|tarde|manha|noite|amanha|hoje|meio|meia)\b',
    ).hasMatch(low);
  }

  /// Remove frases de hora falada («duas da tarde», «meio-dia», etc.).
  @visibleForTesting
  static String stripColloquialTimePhrasesPT(String text) {
    var t = normPT(text);

    t = t.replaceAll(RegExp(r'\bmeio[\s-]?dia\b'), ' ');
    t = t.replaceAll(RegExp(r'\bmeia[\s-]?noite\b'), ' ');

    t = t.replaceAll(
      RegExp(
        r'\b(?:as|a|às|à)?\s*'
        r'(uma|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|onze|doze)'
        r'(?:\s+e\s+meia)?\s+da\s+tarde\b',
      ),
      ' ',
    );
    t = t.replaceAll(
      RegExp(
        r'\b(?:as|a|às|à)?\s*'
        r'(uma|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|onze|doze)'
        r'(?:\s+e\s+meia)?\s+da\s+manha\b',
      ),
      ' ',
    );

    t = t.replaceAll(
      RegExp(
        r'\b(uma|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|onze|doze)\b',
      ),
      ' ',
    );
    t = t.replaceAll(RegExp(r'\b(?:da\s+)?(?:tarde|manha|noite)\b'), ' ');

    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _titleFromTranscriptCore(
    String transcript, {
    ExtractPlaceResult? place,
    ExtractErrandListResult? errand,
    required bool hasTime,
    required bool hasDate,
  }) {
    var core = stripColloquialTimePhrasesPT(transcript);
    if (place != null) {
      core = stripPlaceFromTitle(core, place);
    }
    if (errand != null) {
      core = stripErrandFromTitle(core, errand);
    }
    core = stripTemporalResidualPT(core);
    core = cleanTitlePT(
      core,
      hasTime: hasTime,
      hasDate: hasDate,
    );
    return finalizeTitlePT(smartTitleRepairPT(core)).trim();
  }

  static String _polishTitle({
    required String title,
    required String transcript,
    ExtractPlaceResult? place,
    ExtractErrandListResult? errand,
    required bool hasTime,
    required bool hasDate,
  }) {
    var t = title;

    if (place != null) {
      t = stripPlaceFromTitle(t, place);
    }
    if (errand != null) {
      t = stripErrandFromTitle(t, errand);
    }

    t = stripTemporalResidualPT(t);
    if (hasTime) {
      t = stripColloquialTimePhrasesPT(t);
    }
    t = finalizeTitlePT(smartTitleRepairPT(t));

    if (t.isEmpty) {
      t = cleanTitlePT(
        transcript,
        hasTime: hasTime,
        hasDate: hasDate,
      );
      t = finalizeTitlePT(smartTitleRepairPT(t));
    }

    return t.trim();
  }

  static String _extractTextFromGeminiResponse(String body) {
    final root = jsonDecode(body);
    if (root is! Map<String, dynamic>) {
      throw GeminiMagicTaskParserException('Corpo Gemini inválido.');
    }

    final candidates = root['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      final blockReason = root['promptFeedback']?['blockReason'];
      throw GeminiMagicTaskParserException(
        'Gemini sem candidatos${blockReason != null ? ': $blockReason' : ''}.',
      );
    }

    final first = candidates.first;
    if (first is! Map<String, dynamic>) {
      throw GeminiMagicTaskParserException('Candidato Gemini inválido.');
    }

    final content = first['content'];
    if (content is! Map<String, dynamic>) {
      throw GeminiMagicTaskParserException('Conteúdo Gemini ausente.');
    }

    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw GeminiMagicTaskParserException('Partes Gemini ausentes.');
    }

    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map<String, dynamic>) {
        final text = part['text'];
        if (text is String && text.trim().isNotEmpty) {
          buffer.write(text);
        }
      }
    }

    final joined = buffer.toString().trim();
    if (joined.isEmpty) {
      throw GeminiMagicTaskParserException('Texto Gemini vazio.');
    }
    return joined;
  }

  static GeminiMagicTaskParseResult _mapToResult(
    Map<String, dynamic> map, {
    required String fallbackReferenceYmd,
  }) {
    final title = (map['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) {
      throw GeminiMagicTaskParserException('Gemini retornou título vazio.');
    }

    final dateYmd = _normalizeDateYmd(map['dateYmd']);
    final timeHHMM = _normalizeTimeHHMM(map['timeHHMM']);

    final placeRaw = map['placeSearchQuery'];
    final placeSearchQuery = placeRaw is String && placeRaw.trim().isNotEmpty
        ? placeRaw.trim()
        : null;

    final placeSkipGeocoding = map['placeSkipGeocoding'] == true;

    final errandItems = _parseErrandItems(map['errandItems']);

    final iconKey = _normalizeIconKey(map['iconKey']);

    return GeminiMagicTaskParseResult(
      title: title,
      dateYmd: dateYmd,
      timeHHMM: timeHHMM,
      placeSearchQuery: placeSearchQuery,
      placeSkipGeocoding: placeSkipGeocoding,
      errandItems: errandItems,
      iconKey: iconKey,
    );
  }

  static String? _normalizeDateYmd(Object? raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return null;

    final parts = text.split('-');
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;

    final date = DateTime(y, m, d);
    if (date.year != y || date.month != m || date.day != d) return null;
    return TaskStore.formatDateYmd(date);
  }

  static String? _normalizeTimeHHMM(Object? raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;

    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
    if (match == null) return null;

    final hh = int.tryParse(match.group(1)!);
    final mm = int.tryParse(match.group(2)!);
    if (hh == null || mm == null || hh > 23 || mm > 59) return null;

    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  static List<String> _parseErrandItems(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String? _normalizeIconKey(Object? raw) {
    if (raw == null) return null;
    final key = raw.toString().trim().toLowerCase();
    if (key.isEmpty || key == 'null') return null;
    if (!_validIconKeys.contains(key)) return null;
    return key;
  }

  /// Resolve ícone com fallback seguro para o catálogo do app.
  static String resolveIconKey(String? geminiIconKey) {
    if (geminiIconKey != null &&
        TaskIconCatalog.icons.any((o) => o.key == geminiIconKey)) {
      return geminiIconKey;
    }
    return TaskIconCatalog.defaultIconKey;
  }

  static int resolveIconBackgroundArgb(String iconKey) {
    for (var i = 0; i < TaskIconCatalog.icons.length; i++) {
      if (TaskIconCatalog.icons[i].key == iconKey &&
          i < TaskIconCatalog.colors.length) {
        return TaskIconCatalog.colors[i].backgroundArgb;
      }
    }
    return TaskIconCatalog.defaultColor.backgroundArgb;
  }
}

class GeminiMagicTaskParserException implements Exception {
  GeminiMagicTaskParserException(this.message);

  final String message;

  @override
  String toString() => 'GeminiMagicTaskParserException: $message';
}

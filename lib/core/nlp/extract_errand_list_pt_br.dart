import 'extract_place_pt_br.dart';
import 'extract_when_pt_br.dart';

/// Lista de itens (compras, etc.) extraída de um local no transcript.
class ExtractErrandListResult {
  const ExtractErrandListResult({
    required this.description,
    required this.matchedText,
    required this.items,
    this.verb = 'comprar',
  });

  /// Texto multilinha para [Task.descricao] (marcadores •).
  final String description;

  /// Trecho original a remover do título.
  final String matchedText;

  final List<String> items;

  /// Verbo principal detectado: comprar, pegar, buscar…
  final String verb;
}

/// Limite do trecho de itens antes de data/hora ou fim.
const _listStopLookahead =
    r'(?=\s+(?:de|da|do)\s+(?:tarde|manha|noite|madrugada|almoco)|'
    r'\s+(?:hoje|amanha|depois|agora|cedo)|'
    r'\s+as\s+\d{1,2}|'
    r'\s+\d{1,2}(?::\d{2})?\s*(?:h|hs|horas?)\b|'
    r'\s+(?:no|na|nem|em|ao|à)\s+[\p{L}]|'
    r'$)';

const _itemStopWords = {
  'la',
  'lá',
  'tambem',
  'também',
  'tudo',
  'isso',
  'aquilo',
  'depois',
  'antes',
  'agora',
  'hoje',
  'amanha',
  'tarde',
  'manha',
  'noite',
  'madrugada',
  'almoco',
  'cedo',
  'so',
  'só',
  'ja',
  'já',
  'ali',
  'aqui',
};

String _capFirst(String s) {
  final t = s.trim();
  if (t.isEmpty) return t;
  return t[0].toUpperCase() + t.substring(1);
}

bool _isValidItem(String raw) {
  final t = raw.trim();
  if (t.length < 2) return false;
  final n = normPT(t);
  if (_itemStopWords.contains(n)) return false;
  if (RegExp(r'^\d{1,2}$').hasMatch(n)) return false;
  if (RegExp(
    r'^(hoje|amanha|tarde|manha|noite|madrugada|almoco|cedo|as|a)$',
  ).hasMatch(n)) {
    return false;
  }
  return RegExp(r'[\p{L}]', unicode: true).hasMatch(t);
}

String _cleanItem(String raw) {
  var s = raw.trim();
  s = s.replaceAll(RegExp(r'^[•\-–—]\s*'), '');
  s = s.replaceAll(RegExp(r'^(?:um|uma|uns|umas)\s+', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'[.,;]+$'), '').trim();
  return s;
}

/// Expande «mamao banana» → dois itens quando não há vírgula explícita.
List<String> _expandItemSegment(String segment) {
  final cleaned = _cleanItem(segment);
  if (cleaned.isEmpty) return const [];

  final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length <= 1) {
    return _isValidItem(cleaned) ? [cleaned] : const [];
  }

  final allValidWords = words.every((w) => _isValidItem(w) && w.length <= 24);
  if (allValidWords) return words;

  return _isValidItem(cleaned) ? [cleaned] : const [];
}

/// Extrai o trecho de itens do transcript original (preserva acentos).
String? extractOriginalErrandChunk(String original) {
  final m = RegExp(
    r'\b(comprar|pegar|buscar|levantar|adquirir)\s+'
    r'([\p{L}\p{N}][\p{L}\p{N}\s,;/\-e]*?)'
    r'(?:\s+(?:no|na|nem|em|ao|à|aos|nas|nos)\s+[\p{L}]|'
    r'\s+de\s+(?:tarde|manh[aã]|noite|madrugada|almo[cç]o|cedo)\b|'
    r'\s+(?:hoje|amanh[aã]|depois|agora)\b|$)',
    caseSensitive: false,
    unicode: true,
  ).firstMatch(original.trim());
  return m?.group(2)?.trim();
}

/// Separa itens por vírgula, «e» ou palavras soltas (ex.: «mamão banana e açúcar»).
List<String> parseErrandItems(String chunk) {
  var s = chunk.trim();
  if (s.isEmpty) return const [];

  s = s.replaceAll(
    RegExp(
      r'\s+(?:de|da|do)\s+(?:tarde|manh[aã]|noite|madrugada|almo[cç]o|cedo)\b.*$',
      caseSensitive: false,
    ),
    '',
  );
  // normPT troca vírgulas por espaço — recoloca separador antes de colapsar.
  s = s.replaceAll(RegExp(r'\s{2,}'), ', ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

  final items = <String>[];
  for (final part in s.split(RegExp(r'\s*[,;]\s*|\s+e\s+', caseSensitive: false))) {
    items.addAll(_expandItemSegment(part));
  }
  return items;
}

class _ErrandMatch {
  const _ErrandMatch({
    required this.itemsChunk,
    required this.matchedText,
    required this.verb,
    required this.priority,
  });

  final String itemsChunk;
  final String matchedText;
  final String verb;
  final int priority;
}

_ErrandMatch? _tryErrandPattern(
  String text,
  String low, {
  required RegExp pattern,
  required int priority,
  required String Function(RegExpMatch m) itemsFromMatch,
  required String Function(RegExpMatch m) verbFromMatch,
  String Function(RegExpMatch m)? matchedFromMatch,
}) {
  final m = pattern.firstMatch(low);
  if (m == null) return null;

  final chunk = itemsFromMatch(m).trim();
  if (chunk.length < 2) return null;

  final items = parseErrandItems(chunk);
  if (items.isEmpty) return null;

  final matched = matchedFromMatch != null
      ? matchedFromMatch(m).trim()
      : (m.group(0) ?? '').trim();
  if (matched.isEmpty) return null;

  return _ErrandMatch(
    itemsChunk: chunk,
    matchedText: _sliceOriginal(text, low, m.start, m.end, matched),
    verb: verbFromMatch(m),
    priority: priority,
  );
}

/// Recupera o trecho original (com acentos) pelo offset em [low].
String _sliceOriginal(String original, String low, int start, int end, String fallback) {
  if (start < 0 || end > low.length || start >= end) return fallback;
  // Mesmo comprimento na maioria dos casos após normPT.
  if (original.length == low.length) {
    return original.substring(start, end).trim();
  }
  return fallback;
}

String formatErrandDescription(List<String> items) =>
    items.map((i) => '• ${_capFirst(i)}').join('\n');

/// Rótulo exibido no card principal quando a descrição é uma lista estruturada.
const String errandListSummaryLabel = 'Lista de afazeres';

final RegExp _errandBulletLine = RegExp(r'^[•\-–—]\s*(.+)$');

/// Itens de uma descrição gravada com [formatErrandDescription].
List<String> parseErrandListFromDescription(String descricao) {
  final lines = descricao
      .trim()
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty);

  final items = <String>[];
  for (final line in lines) {
    final match = _errandBulletLine.firstMatch(line);
    if (match == null) return const [];
    final item = match.group(1)!.trim();
    if (item.isEmpty) return const [];
    items.add(item);
  }
  return items;
}

bool isErrandListDescription(String descricao) =>
    parseErrandListFromDescription(descricao).isNotEmpty;

/// Lista em uma linha para preview (home) — ex.: «Mamão, Banana, Açúcar».
String errandListInlineFromDescription(String descricao) {
  final items = parseErrandListFromDescription(descricao);
  if (items.isEmpty) return descricao.trim();
  return items.join(', ');
}

String errandTitleForPlace(String placeQuery, String verb) {
  final name = _capFirst(placeQuery.trim());
  return switch (normPT(verb)) {
    'pegar' || 'passar para pegar' => 'Pegar no $name',
    'buscar' || 'levantar' => 'Buscar no $name',
    'fazer compras' => 'Compras no $name',
    _ => 'Comprar no $name',
  };
}

/// Extrai lista de itens após verbos como «comprar», «pegar», «buscar».
///
/// Com [place], aceita lista com um único item; sem local, exige 2+ itens
/// ou separadores explícitos (vírgula / «e»).
ExtractErrandListResult? extractErrandListPTBR(
  String transcript, {
  ExtractPlaceResult? place,
}) {
  final text = dedupeRepeatedSpeech(transcript.trim());
  if (text.isEmpty) return null;

  final low = normPT(text);
  final candidates = <_ErrandMatch>[];

  void add(_ErrandMatch? m) {
    if (m != null) candidates.add(m);
  }

  // «fazer compras no X: arroz, feijão» / «compras: a, b e c».
  add(_tryErrandPattern(
    text,
    low,
    priority: 95,
    pattern: RegExp(
      '\\b(?:fazer\\s+)?compras\\s*'
      '(?:no|na|em|ao|à)?\\s*[^:,-]{0,40}?'
      '[:\\-–—]\\s*'
      '([\\p{L}\\p{N}][\\p{L}\\p{N}\\s,;/\\-e]+?)'
      '$_listStopLookahead',
      unicode: true,
      caseSensitive: false,
    ),
    itemsFromMatch: (m) => m.group(1) ?? '',
    verbFromMatch: (_) => 'comprar',
    matchedFromMatch: (m) => m.group(0) ?? '',
  ));

  // «ir / vou no X comprar a, b e c».
  add(_tryErrandPattern(
    text,
    low,
    priority: 90,
    pattern: RegExp(
      '\\b(?:ir|vou|preciso|tenho\\s+que)\\s+'
      '(?:no|na|nem|em|ao|à|aos|nas|nos)?\\s*'
      '[\\p{L}\\p{N}\\s\\-]{0,45}?'
      '\\s*(comprar|pegar|buscar|levantar)\\s+'
      '([\\p{L}\\p{N}][\\p{L}\\p{N}\\s,;/\\-e]+?)'
      '$_listStopLookahead',
      unicode: true,
      caseSensitive: false,
    ),
    itemsFromMatch: (m) => m.group(2) ?? '',
    verbFromMatch: (m) => normPT(m.group(1) ?? 'comprar'),
    matchedFromMatch: (m) => m.group(0) ?? '',
  ));

  // «comprar banana, maçã e mamão» (com ou sem local antes).
  add(_tryErrandPattern(
    text,
    low,
    priority: 85,
    pattern: RegExp(
      '\\b(comprar|pegar|buscar|levantar|adquirir)\\s+'
      '([\\p{L}\\p{N}][\\p{L}\\p{N}\\s,;/\\-e]+?)'
      '$_listStopLookahead',
      unicode: true,
      caseSensitive: false,
    ),
    itemsFromMatch: (m) => m.group(2) ?? '',
    verbFromMatch: (m) => normPT(m.group(1) ?? 'comprar'),
    matchedFromMatch: (m) => m.group(0) ?? '',
  ));

  if (candidates.isEmpty) return null;

  candidates.sort((a, b) => b.priority.compareTo(a.priority));
  final best = candidates.first;

  final originalChunk = extractOriginalErrandChunk(text);
  final items = originalChunk != null && originalChunk.isNotEmpty
      ? parseErrandItems(originalChunk)
      : parseErrandItems(best.itemsChunk);
  if (items.isEmpty) return null;

  final hasExplicitList =
      best.itemsChunk.contains(',') ||
      RegExp(r'\s+e\s+', caseSensitive: false).hasMatch(best.itemsChunk);

  if (place == null) {
    if (items.length < 2 && !hasExplicitList) return null;
  } else {
    if (items.isEmpty) return null;
  }

  return ExtractErrandListResult(
    description: formatErrandDescription(items),
    matchedText: best.matchedText,
    items: items,
    verb: best.verb,
  );
}

/// Remove trecho da lista do título.
String stripErrandFromTitle(String title, ExtractErrandListResult errand) {
  var t = title;
  if (errand.matchedText.trim().length >= 3) {
    t = removePhraseInsensitive(t, errand.matchedText);
  }
  for (final item in errand.items) {
    if (item.length >= 3) {
      t = removePhraseInsensitive(t, item);
    }
  }
  t = t.replaceAll(
    RegExp(
      r'\b(?:comprar|pegar|buscar|levantar|adquirir|fazer\s+compras)\b',
      caseSensitive: false,
    ),
    ' ',
  );
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

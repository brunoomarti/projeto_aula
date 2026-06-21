import 'extract_place_pt_br.dart';
import 'extract_when_pt_br.dart';

/// Lista de itens (compras, etc.) extraída de um local no transcript.
class ExtractErrandListResult {
  const ExtractErrandListResult({
    required this.description,
    required this.matchedText,
    required this.items,
    this.verb = 'comprar',
    this.parentTitle,
    this.isActionList = false,
  });

  /// Texto multilinha para [Task.descricao] (marcadores •).
  final String description;

  /// Trecho original a remover do título.
  final String matchedText;

  final List<String> items;

  /// Verbo principal detectado: comprar, pegar, buscar…
  final String verb;

  /// Título-mãe quando a lista agrupa várias ações (ex.: «Ir na rua»).
  final String? parentTitle;

  /// Itens são frases de ação, não só produtos.
  final bool isActionList;
}

/// Limite do trecho de itens antes de data/hora ou fim.
const _listStopLookahead =
    r'(?=\s+(?:de|da|do)\s+(?:tarde|manha|noite|madrugada|almoco)|'
    r'\s+(?:hoje|amanha|depois|agora|cedo)|'
    r'\s+as\s+\d{1,2}|'
    r'\s+\d{1,2}(?::\d{2})?\s*(?:h|hs|horas?)\b|'
    r'\s+(?:no|na|nem|em|ao|à)\s+[\p{L}]|'
    r'$)';

/// Limite para listas de ações — permite «no Mercadão», «na Musa» dentro dos itens.
const _actionListStopLookahead =
    r'(?=\s+(?:de|da|do)\s+(?:tarde|manha|noite|madrugada|almoco)|'
    r'\s+(?:hoje|amanha|depois|agora|cedo)|'
    r'\s+as\s+\d{1,2}|'
    r'\s+\d{1,2}(?::\d{2})?\s*(?:h|hs|horas?)\b|'
    r'$)';

const _actionVerbPattern =
    r'(?:comprar|pegar|buscar|pagar|levantar|levar|retirar|tirar|resolver|fazer|ver|visitar|entregar|mandar|depositar|sacar|consultar|agendar|marcar|passar|trocar|devolver|enviar|receber|adquirir|ir|voltar|encomendar|separar|procurar)';

const _feminineDestinationPrefixes = {
  'rua',
  'cidade',
  'praça',
  'praca',
  'avenida',
  'faculdade',
  'escola',
  'farmacia',
  'loja',
  'praia',
  'igreja',
  'clinica',
  'sala',
  'unidade',
  'feira',
};

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
  // Conectores — nunca são itens de lista sozinhos.
  'de',
  'do',
  'da',
  'dos',
  'das',
  'dum',
  'duma',
  'num',
  'numa',
  'no',
  'na',
  'nos',
  'nas',
  'em',
  'ao',
  'aos',
  'a',
  'o',
  'os',
  'as',
  'um',
  'uma',
  'uns',
  'umas',
  'e',
  'para',
  'pro',
  'pra',
  'com',
  'sem',
  'por',
};

/// Preposições/artigos que ligam um único produto («camisa do brasil»).
const _phraseConnectors = {
  'de',
  'do',
  'da',
  'dos',
  'das',
  'dum',
  'duma',
  'num',
  'numa',
  'no',
  'na',
  'nos',
  'nas',
  'em',
  'ao',
  'aos',
  'com',
  'sem',
  'por',
  'para',
  'pro',
  'pra',
};

bool isConnectorOnlyWord(String word) =>
    _phraseConnectors.contains(normPT(word.trim()));

/// Frase descreve um produto único, não vários itens soltos.
bool looksLikeBoundProductPhrase(String text) {
  final words = normPT(text)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.length < 2) return false;
  return words.any(isConnectorOnlyWord);
}

/// Qualificadores de produto (cor, tamanho, tipo) — «tênis branco», «leite integral».
const _productDescriptorWords = {
  'branco', 'branca', 'preto', 'preta', 'azul', 'vermelho', 'vermelha',
  'verde', 'amarelo', 'amarela', 'rosa', 'cinza', 'marrom', 'bege',
  'laranja', 'roxo', 'roxa', 'dourado', 'dourada', 'prata', 'prateado',
  'bronze', 'colorido', 'colorida', 'estampado', 'estampada', 'listrado',
  'listrada', 'liso', 'lisa', 'floral',
  'grande', 'media', 'medio', 'pequeno', 'pequena', 'gg', 'g', 'm', 'p',
  'xg', 'xxg', 'plus', 'infantil', 'adulto',
  'integral', 'desnatado', 'desnatada', 'magro', 'magra', 'light', 'diet',
  'frances', 'francesa', 'italiano', 'italiana', 'caseiro', 'caseira',
  'novo', 'nova', 'usado', 'usada', 'seminovo', 'seminova',
  'couro', 'algodao', 'lona', 'sintetico', 'sintetica', 'esportivo',
  'esportiva', 'social', 'casual', 'longo', 'longa', 'curto', 'curta',
};

bool isProductDescriptorWord(String word) =>
    _productDescriptorWords.contains(normPT(word.trim()));

/// «tênis branco», «leite integral», «camisa azul» — um produto, não lista.
bool looksLikeNounDescriptorPhrase(String text) {
  final words = normPT(_cleanItem(text))
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.length < 2) return false;
  if (words.any(isConnectorOnlyWord)) return false;

  if (isProductDescriptorWord(words.last)) return true;

  // «tênis 42», «camisa 14» — numeração de tamanho.
  if (words.length == 2 && RegExp(r'^\d{1,2}$').hasMatch(words.last)) {
    return true;
  }

  return false;
}

bool looksLikeSingleProductPhrase(String text) =>
    looksLikeBoundProductPhrase(text) || looksLikeNounDescriptorPhrase(text);

bool _sourceChunkHasExplicitList(String? sourceChunk) {
  if (sourceChunk == null) return false;
  return sourceChunk.contains(',') ||
      RegExp(r'\s+e\s+', caseSensitive: false).hasMatch(sourceChunk);
}

bool _shouldMergeToSingleProduct({
  required List<String> valid,
  String? sourceChunk,
}) {
  if (valid.length < 2 || sourceChunk == null) return false;
  if (_sourceChunkHasExplicitList(sourceChunk)) return false;

  final merged = _cleanItem(sourceChunk);
  if (!_isValidItem(merged)) return false;

  if (looksLikeSingleProductPhrase(merged)) return true;
  if (valid.length == 2 && isProductDescriptorWord(valid[1])) return true;

  final joined = valid.join(' ');
  return looksLikeNounDescriptorPhrase(joined);
}

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
  s = s.replaceAll(
    RegExp(r'^(?:um|uma|uns|umas)\s+', caseSensitive: false),
    '',
  );
  s = s.replaceAll(RegExp(r'[.,;]+$'), '').trim();
  return s;
}

/// Expande «mamao banana» → dois itens quando não há vírgula explícita.
/// Mantém «camisa do brasil» como um único item.
List<String> _expandItemSegment(String segment) {
  final cleaned = _cleanItem(segment);
  if (cleaned.isEmpty) return const [];

  final words = cleaned
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.length <= 1) {
    return _isValidItem(cleaned) ? [cleaned] : const [];
  }

  if (looksLikeSingleProductPhrase(cleaned)) {
    return _isValidItem(cleaned) ? [cleaned] : const [];
  }

  final allValidWords = words.every((w) => _isValidItem(w) && w.length <= 24);
  if (allValidWords) return words;

  return _isValidItem(cleaned) ? [cleaned] : const [];
}

/// Corrige listas fragmentadas (ex.: «camisa», «do», «brasil» → um item).
List<String> coalesceErrandItems(
  List<String> items, {
  String? sourceChunk,
}) {
  if (items.isEmpty) return const [];

  final valid = items
      .map(_cleanItem)
      .where((i) => _isValidItem(i) && !isConnectorOnlyWord(i))
      .toList();
  if (valid.isEmpty && sourceChunk != null) {
    final merged = _cleanItem(sourceChunk);
    return _isValidItem(merged) ? [merged] : const [];
  }
  if (valid.length <= 1) return valid;

  if (_shouldMergeToSingleProduct(valid: valid, sourceChunk: sourceChunk)) {
    return [_cleanItem(sourceChunk!)];
  }

  final hasConnectorFragments = items.any(isConnectorOnlyWord);
  if (hasConnectorFragments && sourceChunk != null) {
    final merged = _cleanItem(sourceChunk);
    if (!_sourceChunkHasExplicitList(sourceChunk) && _isValidItem(merged)) {
      return [merged];
    }
  }

  return valid;
}

/// Lista de produtos (2+ itens distintos), não um único produto composto.
bool isProductErrandList(List<String> items) {
  if (items.length < 2) return false;
  return !errandItemsLookLikeActions(items);
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

bool _startsWithActionVerb(String text) {
  final low = normPT(text.trim());
  if (low.isEmpty) return false;
  return RegExp('^$_actionVerbPattern\\b').hasMatch(low);
}

bool _looksLikeActionPhrase(String text) {
  final t = text.trim();
  if (t.isEmpty) return false;
  if (_startsWithActionVerb(t)) return true;
  return t.split(RegExp(r'\s+')).length >= 4;
}

/// Itens são frases de ação (ex.: «Pagar conta no Mercadão»), não só produtos.
bool errandItemsLookLikeActions(List<String> items) {
  if (items.isEmpty) return false;
  final actionLike = items.where(_looksLikeActionPhrase).length;
  return actionLike >= 2 || (items.length == 1 && actionLike == 1);
}

String errandParentTitleFromDestination(String destination) {
  final d = destination.trim();
  if (d.isEmpty) return '';

  final firstWord = normPT(d.split(RegExp(r'\s+')).first);
  final prep = _feminineDestinationPrefixes.contains(firstWord) ? 'na' : 'no';
  return _capFirst('Ir $prep $d');
}

List<String> _segmentActionChunk(String s) {
  final commaParts = s.split(RegExp(r'\s*,\s*'));
  if (commaParts.length > 1) return commaParts;

  final eSplit = _splitActionSegmentByE(s);
  if (eSplit.length >= 2) return eSplit;

  final verbSplit = _splitByActionVerbs(s);
  if (verbSplit.length >= 2) return verbSplit;

  return [s];
}

List<String> _splitByActionVerbs(String s) {
  final re = RegExp(r'\b(' + _actionVerbPattern + r')\b', caseSensitive: false);
  final matches = re.allMatches(s).toList();
  if (matches.length < 2) return [s];

  final parts = <String>[];
  for (var i = 0; i < matches.length; i++) {
    final start = matches[i].start;
    final end = i + 1 < matches.length ? matches[i + 1].start : s.length;
    parts.add(s.substring(start, end).trim());
  }
  return parts;
}

List<String> _splitActionSegmentByE(String segment) {
  final trimmed = segment.trim();
  if (trimmed.isEmpty) return const [];

  final re = RegExp(
    r'\s+e\s+(?:' + _actionVerbPattern + r')\b',
    caseSensitive: false,
  );
  if (!re.hasMatch(trimmed)) return [trimmed];

  final items = <String>[];
  var start = 0;
  for (final match in re.allMatches(trimmed)) {
    items.add(
      trimmed
          .substring(start, match.start)
          .trim()
          .replaceAll(RegExp(r'\s+e\s*$', caseSensitive: false), '')
          .trim(),
    );
    start = match.start + 3;
  }
  if (start < trimmed.length) {
    items.add(trimmed.substring(start).trim());
  }
  return items.where((s) => s.isNotEmpty).toList();
}

bool _isValidActionErrandItem(String raw) {
  final cleaned = _cleanItem(raw);
  if (!_isValidItem(cleaned)) return false;
  return _looksLikeActionPhrase(cleaned);
}

/// Separa ações completas por vírgula e «e» antes de verbos.
List<String> parseActionErrandItems(String chunk) {
  var s = chunk.trim();
  if (s.isEmpty) return const [];

  s = s.replaceAll(
    RegExp(
      r'\s+(?:de|da|do)\s+(?:tarde|manh[aã]|noite|madrugada|almo[cç]o|cedo)\b.*$',
      caseSensitive: false,
    ),
    '',
  );
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

  final items = <String>[];
  for (final part in _segmentActionChunk(s)) {
    items.addAll(_splitActionSegmentByE(part));
  }

  return items
      .map(_cleanItem)
      .where(_isValidActionErrandItem)
      .map(_capFirst)
      .toList();
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
  for (final part in s.split(
    RegExp(r'\s*[,;]\s*|\s+e\s+', caseSensitive: false),
  )) {
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
    this.destination,
  });

  final String itemsChunk;
  final String matchedText;
  final String verb;
  final int priority;
  final String? destination;
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

  var items = parseErrandItems(chunk);
  items = coalesceErrandItems(items, sourceChunk: chunk);
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
String _sliceOriginal(
  String original,
  String low,
  int start,
  int end,
  String fallback,
) {
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

/// Título quando há lista de produtos, mas sem local nomeado (ex.: mercado).
String errandTitleWithoutPlace(String verb) {
  return switch (normPT(verb)) {
    'pegar' => 'Lista para pegar',
    'buscar' || 'levantar' => 'Lista para buscar',
    'fazer compras' => 'Lista de compras',
    _ => 'Lista de compras',
  };
}

/// Título exibido quando há lista de afazeres (compras ou ações).
String resolveErrandDisplayTitle({
  required String primaryTitle,
  ExtractPlaceResult? place,
  ExtractErrandListResult? errand,
  required List<String> errandItems,
}) {
  final trimmed = primaryTitle.trim();
  if (errandItemsLookLikeActions(errandItems)) {
    if (errand?.parentTitle != null && errand!.parentTitle!.trim().isNotEmpty) {
      return errand.parentTitle!.trim();
    }
    if (trimmed.isNotEmpty) return trimmed;
  }

  if (place != null && errandItems.isNotEmpty) {
    final verb = errand?.verb ?? 'comprar';
    if (errandItems.length == 1 && !errandItemsLookLikeActions(errandItems)) {
      return _capFirst('$verb ${errandItems.first}');
    }
    return errandTitleForPlace(place.searchQuery, verb);
  }

  if (isProductErrandList(errandItems)) {
    final verb = errand?.verb ?? 'comprar';
    return errandTitleWithoutPlace(verb);
  }

  return trimmed;
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

  // «preciso ir na rua para pagar X, comprar Y, buscar Z».
  add(_tryActionErrandPattern(text, low));

  // «fazer compras no X: arroz, feijão» / «compras: a, b e c».
  add(
    _tryErrandPattern(
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
    ),
  );

  // «ir / vou no X comprar a, b e c».
  add(
    _tryErrandPattern(
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
    ),
  );

  // «comprar banana, maçã e mamão» (com ou sem local antes).
  add(
    _tryErrandPattern(
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
    ),
  );

  if (candidates.isEmpty) return null;

  candidates.sort((a, b) => b.priority.compareTo(a.priority));
  final best = candidates.first;

  List<String> items;
  if (best.priority >= 100) {
    items = parseActionErrandItems(best.itemsChunk);
  } else {
    final originalChunk = extractOriginalErrandChunk(text);
    items = originalChunk != null && originalChunk.isNotEmpty
        ? parseErrandItems(originalChunk)
        : parseErrandItems(best.itemsChunk);
    items = coalesceErrandItems(
      items,
      sourceChunk: originalChunk ?? best.itemsChunk,
    );
  }
  if (items.isEmpty) return null;

  final hasExplicitList =
      best.itemsChunk.contains(',') ||
      RegExp(r'\s+e\s+', caseSensitive: false).hasMatch(best.itemsChunk);

  if (place == null) {
    if (items.length < 2 && !hasExplicitList && best.priority < 100) {
      return null;
    }
  }

  final isActionList =
      best.priority >= 100 || errandItemsLookLikeActions(items);
  final parentTitle = isActionList && best.destination != null
      ? errandParentTitleFromDestination(best.destination!)
      : null;

  return ExtractErrandListResult(
    description: formatErrandDescription(items),
    matchedText: best.matchedText,
    items: items,
    verb: best.verb,
    parentTitle: parentTitle,
    isActionList: isActionList,
  );
}

_ErrandMatch? _tryActionErrandPattern(String text, String low) {
  final m = RegExp(
    r'\b(?:preciso|tenho\s+que|devo|vou|queria|gostaria\s+de)\s+'
    r'(?:ir|passar)\s+'
    r'(?:na|no|nem|em)\s+'
    r'([\p{L}\p{N}\s\-]+?)'
    r'\s+para\s+'
    r'([\p{L}\p{N}][\p{L}\p{N}\s,;/\-]*?)' +
        _actionListStopLookahead,
    unicode: true,
    caseSensitive: false,
  ).firstMatch(low);
  if (m == null) return null;

  final destination = m.group(1)?.trim() ?? '';
  final actionsChunk = m.group(2)?.trim() ?? '';
  if (destination.isEmpty || actionsChunk.isEmpty) return null;

  final items = parseActionErrandItems(actionsChunk);
  if (items.length < 2 && !actionsChunk.contains(',')) return null;
  if (items.isEmpty) return null;

  final matched = m.group(0)?.trim() ?? '';
  if (matched.isEmpty) return null;

  return _ErrandMatch(
    itemsChunk: actionsChunk,
    matchedText: _sliceOriginal(text, low, m.start, m.end, matched),
    verb: normPT(items.first.split(RegExp(r'\s+')).first),
    priority: 100,
    destination: destination,
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
  if (!errand.isActionList) {
    t = t.replaceAll(
      RegExp(
        r'\b(?:comprar|pegar|buscar|levantar|adquirir|fazer\s+compras)\b',
        caseSensitive: false,
      ),
      ' ',
    );
  } else {
    t = t.replaceAll(
      RegExp(
        r'\b(?:preciso|tenho\s+que|devo|vou|queria|gostaria\s+de|ir|passar)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    if (errand.parentTitle != null) {
      t = removePhraseInsensitive(t, errand.parentTitle!);
    }
  }
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

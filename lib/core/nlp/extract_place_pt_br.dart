import 'extract_when_pt_br.dart';

/// Local extraído do transcript para geocodificação.
class ExtractPlaceResult {
  const ExtractPlaceResult({
    required this.searchQuery,
    required this.matchedText,
    this.qualifiers = const [],
    this.skipGeocoding = false,
  });

  /// Texto enviado ao geocoder (Google Places).
  final String searchQuery;

  /// Trecho original a remover do título.
  final String matchedText;

  /// Termos extras para desempate (ex.: campus, cidade).
  final List<String> qualifiers;

  /// Tipo genérico sem nome próprio (ex. «supermercado») — não geocodifica.
  final bool skipGeocoding;
}

/// Palavras só de tipo genérico — sem nome próprio, não geocodifica.
const _kGenericPlaceTokens = {
  'mercado',
  'supermercado',
  'feira',
  'casa',
  'lar',
  'home',
  'trabalho',
  'escritorio',
  'faculdade',
  'escola',
  'universidade',
  'hospital',
  'clinica',
  'academia',
  'farmacia',
  'dentista',
  'medico',
  'consultorio',
  'salao',
  'bar',
  'restaurante',
  'padaria',
  'loja',
  'banco',
  'correios',
  'igreja',
  'templo',
  'parque',
  'praia',
  'centro',
  'servico',
  'oficina',
  'posto',
  'aeroporto',
  'terminal',
  'rodoviaria',
  'estacao',
  'metro',
  'unidade',
  'colegio',
  'creche',
  'clube',
  'predio',
  'edificio',
  'sala',
  'local',
  'lugar',
  'ponto',
  'endereco',
  'conveniencia',
  'lanchonete',
  'lancheria',
  'shopping',
};

/// Verbos de lista/compras — não fazem parte do nome do local.
const _kErrandVerbTokens = {
  'comprar',
  'pegar',
  'buscar',
  'levantar',
  'adquirir',
  'fazer',
};

/// Limite antes de data/hora ou fim de frase ao capturar local.
const _kPlaceStopLookahead =
    r'(?=(?:'
    r'\s+de\s+(?:tarde|manha|noite|madrugada|almoco|cedo)\b'
    r'|\s+(?:hoje|amanha|depois|agora|cedo|tarde|noite|manha|madrugada|almoco|'
    r'as|às|a\s+\d|daqui|para|pra|pro|p\/|comprar|pegar|buscar|levantar|com|que|'
    r'e\s+as|e\s+a|e\s+\d)'
    r'|\s+dia\s+\d{1,2}\b'
    r'|\s+\d{1,2}(?::\d{2})?\s*(?:h|hs|horas?)\b'
    r'|\s+\d{1,2}\s*h\b'
    r'|$))';
const _kKnownQualifiers = {
  'colatina',
  'itapina',
  'serra',
  'vitoria',
  'cachoeiro',
  'linhares',
  'guarapari',
  'castelo',
  'alegre',
  'afonso claudio',
  'marataizes',
  'sao mateus',
  'barra de sao francisco',
  'nova venecia',
  'pinheiros',
  'montanha',
  'domingos martins',
  'vila velha',
  'cariacica',
  'fundao',
  'ibiraçu',
  'ibiracu',
  'anchieta',
  'atilio vivacqua',
  'mimoso do sul',
  'piuma',
  'iconha',
  'apiaca',
  'baixo guandu',
  'carapina',
  'laranjeiras',
  'santa leopoldina',
  'santa teresa',
  'sao gabriel da palha',
  'venda nova do imigrante',
};

const _kInstitutionKeys = {
  'ifes',
  'ufes',
  'unitins',
  'faccamp',
  'estacio',
  'estácio',
  'unesc',
  'multivix',
  'uvv',
  'faesa',
  'dom bosco',
};

class _PlaceMatch {
  const _PlaceMatch({
    required this.searchQuery,
    required this.matchedText,
    required this.start,
    required this.qualifiers,
    required this.priority,
    required this.skipGeocoding,
  });

  final String searchQuery;
  final String matchedText;
  final int start;
  final List<String> qualifiers;
  final int priority;
  final bool skipGeocoding;
}

bool _isTemporalOrGenericWord(String word) {
  const temporal = {
    'hoje', 'amanha', 'depois', 'agora', 'cedo', 'tarde', 'noite', 'manha',
    'madrugada', 'almoco', 'as', 'a', 'daqui', 'para', 'pra', 'com', 'que',
    'de', 'da', 'do', 'dos', 'das', 'em', 'no', 'na', 'nos', 'nas',
  };
  final w = normPT(word);
  return temporal.contains(w) || _kGenericPlaceTokens.contains(w);
}

/// Nome próprio inválido após tipo genérico («no supermercado de tarde»).
bool _isInvalidPlaceProperName(String? name) {
  if (name == null || name.trim().isEmpty) return true;
  final tokens = normPT(name).split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  if (tokens.isEmpty) return true;
  if (tokens.any(_kErrandVerbTokens.contains)) return true;
  return tokens.every(_isTemporalOrGenericWord);
}

String _genericPlaceMatchedText(RegExpMatch m) {
  final type = m.group(1)?.trim() ?? '';
  if (type.isEmpty) return m.group(0)?.trim() ?? '';
  return RegExp(
    '\\b(?:no|na|nem|em|ao|à|aos|nas|nos)\\s+${RegExp.escape(type)}\\b',
    caseSensitive: false,
  ).firstMatch(m.group(0) ?? '')?.group(0)?.trim() ?? type;
}

bool _isGenericOnly(String phrase) {
  final tokens = normPT(phrase)
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty && t != 'campus')
      .toList();
  if (tokens.isEmpty) return true;
  return tokens.every(_kGenericPlaceTokens.contains);
}

String _trimPlaceCapture(String raw) {
  var s = raw.trim();
  s = s.replaceAll(RegExp(r'[,\.;]+$'), '').trim();
  // Corta lixo temporal — \b evita apagar nomes como "atacadao" (começam com "a").
  s = s.replaceAll(
    RegExp(
      r'\s+(?:de|da|do)\s+(?:tarde|manha|noite|madrugada|almoco|cedo)\b\s*.*$',
      caseSensitive: false,
    ),
    '',
  );
  s = s.replaceAll(
    RegExp(
      r'\s+(?:hoje|amanha|depois|agora|cedo|tarde|noite|manha|madrugada|'
      r'almoco|as|às|\bas\b|\ba\b)\b\s*.*$',
      caseSensitive: false,
    ),
    '',
  );
  s = s.replaceAll(
    RegExp(
      r'\s+\d{1,2}(?::\d{2})?\s*(?:h|hs|horas?)?\b\s*$',
      caseSensitive: false,
    ),
    '',
  );
  return s.trim();
}

/// Remove repetição comum do ASR: "ir ao mercado ir ao mercado" → "ir ao mercado".
String dedupeRepeatedSpeech(String text) {
  var t = text.trim();
  if (t.isEmpty) return t;

  final words = t.split(RegExp(r'\s+'));
  if (words.length < 4) return t;

  for (var len = words.length ~/ 2; len >= 2; len--) {
    if (words.length < len * 2) continue;
    final first = words.sublist(0, len);
    final second = words.sublist(len, len * 2);
    if (normPT(first.join(' ')) == normPT(second.join(' '))) {
      final rest = words.length > len * 2
          ? words.sublist(len * 2).join(' ')
          : '';
      return [first.join(' '), rest].where((s) => s.isNotEmpty).join(' ');
    }
  }
  return t;
}

String _sanitizeSearchQuery(String query) {
  var q = _trimPlaceCapture(query);
  const temporal = {
    'hoje', 'amanha', 'depois', 'agora', 'cedo', 'tarde', 'noite', 'manha',
    'madrugada', 'almoco', 'as', 'a', 'daqui', 'para', 'pra', 'com', 'que',
  };
  final tokens = q.split(RegExp(r'\s+'));
  final kept = <String>[];
  for (final token in tokens) {
    if (token.isEmpty) continue;
    final n = normPT(token);
    if (temporal.contains(n)) continue;
    if (RegExp(r'^\d{1,2}(?::\d{2})?(?:h|hs|horas?)?$').hasMatch(n)) continue;
    kept.add(token);
  }
  q = kept.join(' ').trim();
  return _collapseRepeatedPlaceQuery(q);
}

String _collapseRepeatedPlaceQuery(String query) {
  final tokens = query.split(RegExp(r'\s+'));
  if (tokens.length < 4) return query.trim();

  for (var len = tokens.length ~/ 2; len >= 2; len--) {
    if (tokens.length < len * 2) continue;
    final first = tokens.sublist(0, len);
    final second = tokens.sublist(len, len * 2);
    if (normPT(first.join(' ')) == normPT(second.join(' '))) {
      return first.join(' ');
    }
  }
  return query.trim();
}

List<String> _extractQualifiers(String phrase) {
  final low = normPT(phrase);
  final found = <String>[];
  for (final q in _kKnownQualifiers) {
    if (low.contains(normPT(q))) found.add(q);
  }
  final campus = RegExp(r'\bcampus\s+([\p{L}\p{N}\s\-]{2,30})', unicode: true)
      .firstMatch(low);
  if (campus != null) {
    final c = _trimPlaceCapture(campus.group(1)!);
    if (c.isNotEmpty && !_kGenericPlaceTokens.contains(c)) {
      found.add(c);
    }
  }
  return found.toSet().toList();
}

String _buildSearchQuery(String core, List<String> qualifiers) {
  var q = core.trim();
  final low = normPT(q);

  for (final key in _kInstitutionKeys) {
    if (low.contains(normPT(key))) {
      // Mantém sigla legível + qualificadores.
      final parts = <String>[key.toUpperCase()];
      for (final qual in qualifiers) {
        if (!normPT(q).contains(normPT(qual))) {
          parts.add(qual);
        }
      }
      return parts.join(' ');
    }
  }

  if (qualifiers.isNotEmpty) {
    final missing = qualifiers.where(
      (qual) => !normPT(q).contains(normPT(qual)),
    );
    if (missing.isNotEmpty) {
      q = '$q ${missing.join(' ')}';
    }
  }

  return q.replaceAll(RegExp(r'\s+'), ' ').trim();
}

_PlaceMatch? _tryPattern(
  String text,
  String low, {
  required RegExp pattern,
  required int priority,
  required String Function(RegExpMatch match) buildQuery,
  required String Function(RegExpMatch match) buildMatched,
}) {
  final m = pattern.firstMatch(low);
  if (m == null) return null;

  final capture = _sanitizeSearchQuery(buildQuery(m));
  if (capture.length < 2) return null;

  final isGenericOnly = _isGenericOnly(capture);
  final hasErrandVerb = RegExp(
    r'\b(?:comprar|pegar|buscar|levantar|adquirir|fazer\s+compras)\b',
    caseSensitive: false,
  ).hasMatch(low);
  if (isGenericOnly && !hasErrandVerb) return null;

  final matched = _trimPlaceCapture(buildMatched(m)).trim();
  if (matched.isEmpty) return null;

  final qualifiers = _extractQualifiers('$capture ${m.group(0) ?? ''}');
  final searchQuery = _sanitizeSearchQuery(_buildSearchQuery(capture, qualifiers));

  return _PlaceMatch(
    searchQuery: searchQuery,
    matchedText: matched,
    start: m.start,
    qualifiers: qualifiers,
    priority: priority,
    skipGeocoding: isGenericOnly,
  );
}

/// Extrai menção a local nomeado no transcript PT-BR.
ExtractPlaceResult? extractPlacePTBR(String transcript) {
  final text = dedupeRepeatedSpeech(transcript.trim());
  if (text.isEmpty) return null;

  final low = normPT(text);
  final candidates = <_PlaceMatch>[];

  void add(_PlaceMatch? m) {
    if (m != null) candidates.add(m);
  }

  // Instituição + campus/cidade: "no IFES campus Colatina", "na UFES em Vitória".
  add(_tryPattern(
    text,
    low,
    priority: 100,
    pattern: RegExp(
      '\\b(?:no|na|nem|em|ao|à|aos|nas|nos)\\s+'
      '((?:ifes|ufes|unitins|faccamp|estacio|estácio|unesc|multivix|uvv|faesa|dom bosco))'
      '(?:\\s+(?:campus|unidade|polo))?\\s*'
      '([\\p{L}][\\p{L}\\p{N}\\s\\-]{1,30})?'
      '$_kPlaceStopLookahead',
      unicode: true,
      caseSensitive: false,
    ),
    buildQuery: (m) {
      final inst = m.group(1)!;
      final qual = m.group(2)?.trim();
      if (qual != null &&
          qual.isNotEmpty &&
          !_isTemporalOrGenericWord(qual) &&
          !_isGenericOnly(qual)) {
        return '$inst $qual';
      }
      return inst;
    },
    buildMatched: (m) => m.group(0) ?? '',
  ));

  // Endereço explícito.
  add(_tryPattern(
    text,
    low,
    priority: 90,
    pattern: RegExp(
      '\\b(?:rua|av\\.?|avenida|rodovia|rod\\.|praça|praca|travessa|alameda|estrada)\\s+'
      '[\\p{L}\\p{N}\\s\\.,\\-ºª/]{3,80}'
      '$_kPlaceStopLookahead',
      unicode: true,
      caseSensitive: false,
    ),
    buildQuery: (m) => m.group(0) ?? '',
    buildMatched: (m) => m.group(0) ?? '',
  ));

  // Tipo genérico sem nome próprio: "no supermercado comprar ...".
  add(_tryPattern(
    text,
    low,
    priority: 86,
    pattern: RegExp(
      '\\b(?:no|na|nem|em|ao|à|aos|nas|nos)\\s+'
      '(mercado|supermercado|padaria|farmacia|farmácia|posto|loja|salao|salão|'
      'hospital|academia|bar|restaurante|café|cafe|conveniencia|lanchonete|'
      'shopping|feira|banco|correios|igreja|parque|praia)\\b'
      '$_kPlaceStopLookahead',
      unicode: true,
      caseSensitive: false,
    ),
    buildQuery: (m) => m.group(1) ?? '',
    buildMatched: (m) => _genericPlaceMatchedText(m),
  ));

  // Tipo genérico + nome: "no mercado Atacadão", "na padaria Central".
  add(_tryPattern(
    text,
    low,
    priority: 85,
    pattern: RegExp(
      '\\b(?:no|na|nem|em|ao|à)\\s+'
      '(mercado|supermercado|padaria|farmacia|farmácia|posto|loja|salao|salão|'
      'hospital|academia|bar|restaurante|café|cafe)\\s+'
      '(?!comprar|pegar|buscar|levantar|adquirir|fazer\\b)'
      '([\\p{L}\\p{N}][\\p{L}\\p{N}\\s\\-]{1,35}?)'
      '$_kPlaceStopLookahead',
      unicode: true,
      caseSensitive: false,
    ),
    buildQuery: (m) {
      final type = m.group(1)!;
      final name = m.group(2)?.trim();
      if (_isInvalidPlaceProperName(name)) return type;
      return '$type $name';
    },
    buildMatched: (m) {
      if (_isInvalidPlaceProperName(m.group(2)?.trim())) {
        return _genericPlaceMatchedText(m);
      }
      return m.group(0) ?? '';
    },
  ));

  // Estabelecimento nomeado: "no Shopping Vitória", "na Padaria Central".
  add(_tryPattern(
    text,
    low,
    priority: 80,
    pattern: RegExp(
      '\\b(?:no|na|nem|em|ao|à|aos|nas|nos)\\s+'
      '((?:shopping|hospital|hotel|motel|clinica|clínica|academia|restaurante|'
      'bar|café|cafe|padaria|farmacia|farmácia|posto|supermercado|mercado|'
      'loja|salao|salão|barbearia|pet shop|petshop|unidade|polo|campus)\\s+'
      '[\\p{L}\\p{N}][\\p{L}\\p{N}\\s\\-]{1,40}?)'
      '$_kPlaceStopLookahead',
      unicode: true,
      caseSensitive: false,
    ),
    buildQuery: (m) => m.group(1) ?? '',
    buildMatched: (m) => m.group(0) ?? '',
  ));

  // Preposição + nome próprio (siglas, nomes): "no IFES", "em McDonald's", "no Sesc".
  add(_tryPattern(
    text,
    low,
    priority: 70,
    pattern: RegExp(
      '\\b(?:no|na|nem|em|ao|à|aos|nas|nos)\\s+'
      '([\\p{L}\\p{N}][\\p{L}\\p{N}\\.\\-\\s]{1,50}?)'
      '$_kPlaceStopLookahead',
      unicode: true,
      caseSensitive: false,
    ),
    buildQuery: (m) => m.group(1) ?? '',
    buildMatched: (m) => m.group(0) ?? '',
  ));

  // "campus Colatina" / "campus de Colatina" sem repetir instituição no match anterior.
  add(_tryPattern(
    text,
    low,
    priority: 65,
    pattern: RegExp(
      '\\b(?:campus|unidade|polo)\\s+(?:de|da|do)?\\s*'
      '([\\p{L}][\\p{L}\\p{N}\\s\\-]{2,30})'
      '$_kPlaceStopLookahead',
      unicode: true,
      caseSensitive: false,
    ),
    buildQuery: (m) => 'campus ${m.group(1) ?? ''}',
    buildMatched: (m) => m.group(0) ?? '',
  ));

  if (candidates.isEmpty) return null;

  candidates.sort((a, b) {
    final byPriority = b.priority.compareTo(a.priority);
    if (byPriority != 0) return byPriority;
    return a.start.compareTo(b.start);
  });

  final best = candidates.first;
  return ExtractPlaceResult(
    searchQuery: best.searchQuery,
    matchedText: best.matchedText,
    qualifiers: best.qualifiers,
    skipGeocoding: best.skipGeocoding,
  );
}

/// Remove menção ao local do título já parseado.
String stripPlaceFromTitle(String title, ExtractPlaceResult place) {
  if (title.trim().isEmpty) return title;
  var t = title;

  final needles = <String>{
    place.matchedText,
    place.searchQuery,
    ...place.qualifiers,
  };

  for (final part in place.searchQuery.split(RegExp(r'\s+'))) {
    if (part.length >= 3) needles.add(part);
  }

  for (final needle in needles) {
    if (needle.trim().length >= 2) {
      t = removePhraseInsensitive(t, needle);
    }
  }

  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  t = t
      .replaceAll(
        RegExp(r'\b(?:no|na|nem|em|ao|à|aos|nas|nos)\s*$', caseSensitive: false),
        '',
      )
      .trim();
  return t;
}

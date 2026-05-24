/// Extração de data/hora e título limpo a partir de transcript PT-BR (ASR).
/// Port fiel de `tasker-main/src/utils/nlp.js`.
library;

class ExtractWhenResult {
  const ExtractWhenResult({
    required this.title,
    this.dateYmd,
    this.timeHHMM,
  });

  final String title;
  final String? dateYmd;
  final String? timeHHMM;
}

String _pad2(int n) => n.toString().padLeft(2, '0');

String _toYMD(DateTime d) =>
    '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}';

DateTime _addDays(DateTime date, int n) =>
    DateTime(date.year, date.month, date.day + n);

int _clamp(int v, int lo, int hi) =>
    v < lo ? lo : (v > hi ? hi : v);

/// JS `getDay()`: 0=domingo … 6=sábado.
int _jsDayOfWeek(DateTime d) => d.weekday % 7;

String _roundToNext5Min([DateTime? date]) {
  final d = date ?? DateTime.now();
  final mins = d.minute;
  final add = (5 - (mins % 5)) % 5;
  final rounded = DateTime(d.year, d.month, d.day, d.hour, mins + add);
  return '${_pad2(rounded.hour)}:${_pad2(rounded.minute)}';
}

String _capFirst(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

const _accentFrom =
    'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÿÑñ';
const _accentTo =
    'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeCcIIIIiiiiUUUUuuuuyNn';

final Map<String, String> _accentMap = {
  for (var i = 0; i < _accentFrom.length; i++)
    _accentFrom[i]: _accentTo[i],
};

String _removeDiacritics(String s) {
  final buffer = StringBuffer();
  for (final ch in s.split('')) {
    buffer.write(_accentMap[ch] ?? ch);
  }
  return buffer.toString();
}

String _toAccentInsensitivePattern(String s) {
  const map = {
    'a': r'[aáàâãäAÁÀÂÃÄ]',
    'e': r'[eéèêëEÉÈÊË]',
    'i': r'[iíìîïIÍÌÎÏ]',
    'o': r'[oóòôõöOÓÒÔÕÖ]',
    'u': r'[uúùûüUÚÙÛÜ]',
    'c': r'[cçCÇ]',
    'n': r'[nñNÑ]',
  };

  final escaped = s.replaceAllMapped(
    RegExp(r'[-/\\^$*+?.()|[\]{}]'),
    (m) => '\\${m[0]}',
  );

  return escaped.replaceAllMapped(
    RegExp(r'[aeioucñ]', caseSensitive: false),
    (m) => map[m[0]!.toLowerCase()] ?? m[0]!,
  );
}

String _removeAccentInsensitive(String haystack, String needle) {
  if (needle.isEmpty) return haystack;
  final pat = _toAccentInsensitivePattern(needle.trim());
  return haystack.replaceAll(RegExp(pat, caseSensitive: false), ' ');
}

/// Remove [needle] de [haystack] ignorando acentos (limpeza de título).
String removePhraseInsensitive(String haystack, String needle) =>
    _removeAccentInsensitive(haystack, needle)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

/// Normalização agressiva para PT-BR vindo do ASR.
String normPT(String text) {
  return _removeDiacritics(text.toLowerCase())
      .replaceAll(RegExp(r'\bman\b'), 'manha')
      .replaceAllMapped(RegExp(r'\bamanh?a?\b'), (m) {
        final v = m[0]!;
        return v.startsWith('aman') ? 'amanha' : v;
      })
      .replaceAll(RegExp(r'\bterca\b'), 'terca')
      .replaceAll(RegExp(r'\bsabado\b'), 'sabado')
      .replaceAll(RegExp(r'\bmeio\s+dia\b'), 'meio dia')
      .replaceAll(RegExp(r'\bmeia\s+noite\b'), 'meia noite')
      .replaceAll(RegExp(r'\bp\/\b'), 'para')
      .replaceAll(RegExp(r'\bpro?\b'), 'para')
      .replaceAll(RegExp(r'[.,;]+'), ' ');
}

const _weekdays = <String, int>{
  'domingo': 0,
  'segunda': 1,
  'segunda-feira': 1,
  'terca': 2,
  'terca-feira': 2,
  'quarta': 3,
  'quarta-feira': 3,
  'quinta': 4,
  'quinta-feira': 4,
  'sexta': 5,
  'sexta-feira': 5,
  'sabado': 6,
};

const _months = <String, int>{
  'janeiro': 1,
  'fevereiro': 2,
  'marco': 3,
  'abril': 4,
  'maio': 5,
  'junho': 6,
  'julho': 7,
  'agosto': 8,
  'setembro': 9,
  'outubro': 10,
  'novembro': 11,
  'dezembro': 12,
};

const _textNum = <String, int>{
  'zero': 0,
  'uma': 1,
  'um': 1,
  'duas': 2,
  'dois': 2,
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

const _tens = <String, int>{
  'dez': 10,
  'vinte': 20,
  'trinta': 30,
  'quarenta': 40,
  'cinquenta': 50,
};

/// Converte números por extenso simples (até 59).
int? parsePTNumberUpTo59(Object? chunk) {
  final raw = normPT(chunk.toString()).trim();
  if (raw.isEmpty) return null;

  if (RegExp(r'^\d{1,2}$').hasMatch(raw)) return int.parse(raw);
  if (raw == 'meia') return 30;
  if (raw == 'quinze' || raw == 'um quarto' || raw == 'um quarto de hora') {
    return 15;
  }

  final parts = raw.split(RegExp(r'\s+e\s+|\s+')).where((p) => p.isNotEmpty);
  var val = 0;
  for (final p in parts) {
    if (_tens.containsKey(p)) {
      val += _tens[p]!;
    } else if (_textNum.containsKey(p)) {
      val += _textNum[p]!;
    } else if (RegExp(r'^\d+$').hasMatch(p)) {
      val += int.parse(p);
    } else {
      return null;
    }
  }
  if (val >= 0 && val <= 59) return val;
  return null;
}

/// Próxima ocorrência de DOW (JS: 0=dom … 6=sáb).
DateTime nextWeekday(DateTime from, int targetDow) {
  final cur = _jsDayOfWeek(from);
  var delta = (targetDow - cur + 7) % 7;
  if (delta == 0) delta = 7;
  return _addDays(from, delta);
}

class DateParseResult {
  const DateParseResult({required this.date, required this.match});

  final DateTime date;
  final String match;
}

class TimeParseResult {
  const TimeParseResult({required this.time, required this.match});

  final String time;
  final String match;
}

/// Datas explícitas.
DateParseResult? parseExplicitDate(String text, DateTime now) {
  final low = normPT(text);

  var m = RegExp(r'(\d{1,2})[/\-.](\d{1,2})(?:[/\-.](\d{2,4}))?')
      .firstMatch(low);
  if (m != null) {
    final dd = int.parse(m.group(1)!);
    final mm = int.parse(m.group(2)!);
    var yyyy = m.group(3) != null ? int.parse(m.group(3)!) : now.year;
    if (yyyy < 100) yyyy += 2000;
    final d = DateTime(yyyy, mm, dd);
    if (d.month == mm) return DateParseResult(date: d, match: m.group(0)!);
  }

  m = RegExp(
    r'(?:\bdia\s+)?(\d{1,2})\s+de\s+([a-z]+)(?:\s+de\s+(\d{4}))?',
    caseSensitive: false,
  ).firstMatch(low);
  if (m != null) {
    final dd = int.parse(m.group(1)!);
    final mesNome = m.group(2)!;
    final mm = _months[mesNome];
    final yyyy = m.group(3) != null ? int.parse(m.group(3)!) : now.year;
    if (mm != null) {
      final d = DateTime(yyyy, mm, dd);
      if (d.month == mm) {
        return DateParseResult(date: d, match: m.group(0)!);
      }
    }
  }

  return null;
}

/// Datas relativas.
DateParseResult? parseRelativeDate(String text, DateTime now) {
  final low = normPT(text);

  if (RegExp(r'\bhoje\b').hasMatch(low)) {
    return DateParseResult(
      date: DateTime(now.year, now.month, now.day),
      match: 'hoje',
    );
  }
  if (RegExp(r'\bamanha\b').hasMatch(low)) {
    return DateParseResult(date: _addDays(now, 1), match: 'amanha');
  }
  if (RegExp(r'depois\s+de\s+amanha').hasMatch(low)) {
    return DateParseResult(
      date: _addDays(now, 2),
      match: 'depois de amanha',
    );
  }

  var m = RegExp(
    r'\b(?:daqui\s+a|em)\s+(\d+)\s+(dia|dias|semana|semanas)\b',
  ).firstMatch(low);
  if (m != null) {
    final n = int.parse(m.group(1)!);
    final unit = m.group(2)!;
    final days = unit.contains('semana') ? n * 7 : n;
    return DateParseResult(date: _addDays(now, days), match: m.group(0)!);
  }

  m = RegExp(
    r'\b(proxima|proximo)?\s*(domingo|segunda(?:-feira)?|terca(?:-feira)?|quarta(?:-feira)?|quinta(?:-feira)?|sexta(?:-feira)?|sabado)\b',
  ).firstMatch(low);
  if (m != null) {
    final wdKey = m.group(2)!.replaceAll('-feira', '');
    final wd = _weekdays[wdKey] ?? _weekdays[m.group(2)!];
    if (wd != null) {
      return DateParseResult(
        date: nextWeekday(now, wd),
        match: m.group(0)!,
      );
    }
  }

  return null;
}

void _applyAmPmContext(String low, int hh, void Function(int) setHh) {
  final isManha = RegExp(r'\bmanha\b').hasMatch(low);
  final isTarde = RegExp(r'\btarde\b').hasMatch(low);
  final isNoite = RegExp(r'\bnoite\b').hasMatch(low);
  final isPM = RegExp(r'\bpm\b').hasMatch(low);
  final isAM = RegExp(r'\bam\b').hasMatch(low);

  if (hh <= 12) {
    if (isTarde || isNoite || isPM) {
      if (hh != 12) setHh(hh + 12);
    } else if (isManha || isAM) {
      if (hh == 12) setHh(0);
    }
  }
}

/// Inferência de horário por contexto quando não há hora explícita.
TimeParseResult? inferTimeByContext(String text, [DateTime? now]) {
  final low = normPT(text);
  final ref = now ?? DateTime.now();
  RegExpMatch? m;

  if ((m = RegExp(r'(final|fim)\s+do\s+dia').firstMatch(low)) != null) {
    return TimeParseResult(time: '23:59', match: m!.group(0)!);
  }
  if ((m = RegExp(r'(final|fim)\s+da?\s+tarde').firstMatch(low)) != null) {
    return TimeParseResult(time: '17:30', match: m!.group(0)!);
  }
  if ((m = RegExp(r'\bnoite\b|de\s+noite|a\s+noite').firstMatch(low)) !=
      null) {
    return TimeParseResult(time: '23:59', match: m!.group(0)!);
  }
  if ((m = RegExp(r'\btarde\b').firstMatch(low)) != null) {
    return TimeParseResult(time: '15:00', match: m!.group(0)!);
  }
  if ((m = RegExp(r'\b(inicio|comeco)\s+da?\s+tarde\b').firstMatch(low)) !=
      null) {
    return TimeParseResult(time: '13:30', match: m!.group(0)!);
  }
  if ((m = RegExp(r'\bfinal\s+da?\s+manha\b').firstMatch(low)) != null) {
    return TimeParseResult(time: '11:30', match: m!.group(0)!);
  }
  if ((m = RegExp(r'\bmanha\b|de\s+manha|pela\s+manha').firstMatch(low)) !=
      null) {
    return TimeParseResult(time: '09:00', match: m!.group(0)!);
  }
  if ((m = RegExp(r'\b(bem\s+cedo|cedo|primeira\s+hora)\b').firstMatch(low)) !=
      null) {
    return TimeParseResult(time: '08:00', match: m!.group(0)!);
  }
  if ((m = RegExp(r'\b(almoco|hora\s+do\s+almoco)\b').firstMatch(low)) !=
      null) {
    return TimeParseResult(time: '12:00', match: m!.group(0)!);
  }
  if ((m = RegExp(r'\bmadrugada\b').firstMatch(low)) != null) {
    return TimeParseResult(time: '02:00', match: m!.group(0)!);
  }
  if ((m = RegExp(r'\bagora\b').firstMatch(low)) != null) {
    return TimeParseResult(time: _roundToNext5Min(ref), match: m!.group(0)!);
  }

  return null;
}

/// Horas: prioriza "X horas"/"Xh" antes de "hh:mm".
TimeParseResult? parseTime(String text) {
  final low = normPT(text);

  if (RegExp(r'meia[-\s]?noite').hasMatch(low)) {
    final m = RegExp(
      r'(?:\b(?:ao|a|as|às)\s+)?meia\s+noite\b',
      caseSensitive: false,
    ).firstMatch(low);
    return TimeParseResult(
      time: '00:00',
      match: m?.group(0) ?? 'meia noite',
    );
  }
  if (RegExp(r'meio[-\s]?dia').hasMatch(low)) {
    final m = RegExp(
      r'(?:\b(?:ao|a|as|às)\s+)?meio\s+dia\b',
      caseSensitive: false,
    ).firstMatch(low);
    return TimeParseResult(
      time: '12:00',
      match: m?.group(0) ?? 'meio dia',
    );
  }

  var m = RegExp(
    r'(?:\b(as|a)\s*)?(\d{1,2})\s*(?:h|hs|horas?)\s*(?:e\s*([a-z0-9\s]+))?',
    caseSensitive: false,
  ).firstMatch(low);
  if (m != null) {
    var hh = int.parse(m.group(2)!);
    var mm = 0;
    if (m.group(3) != null) {
      final minsRaw = m.group(3)!.trim();
      int? parsedMin;
      final minNum = RegExp(r'(\d{1,2})\s*minutos?').firstMatch(minsRaw);
      if (minNum != null) {
        parsedMin = _clamp(int.parse(minNum.group(1)!), 0, 59);
      }
      parsedMin ??= parsePTNumberUpTo59(minsRaw);
      if (parsedMin != null) mm = parsedMin;
    }

    _applyAmPmContext(low, hh, (v) => hh = v);

    hh = _clamp(hh, 0, 23);
    mm = _clamp(mm, 0, 59);
    return TimeParseResult(
      time: '${_pad2(hh)}:${_pad2(mm)}',
      match: m.group(0)!,
    );
  }

  m = RegExp(
    r'(?:\b(as|a)\s*)?(\d{1,2})(?:[:h](\d{2}))?',
    caseSensitive: false,
  ).firstMatch(low);
  if (m != null) {
    var hh = int.parse(m.group(2)!);
    int? mm = m.group(3) != null ? int.parse(m.group(3)!) : null;

    if (mm == null) {
      final after = low.substring(m.end);
      final w = RegExp(r'^\s*e\s*([a-z0-9\s]+)').firstMatch(after);
      if (w != null) {
        final parsedMin = parsePTNumberUpTo59(w.group(1));
        if (parsedMin != null) mm = parsedMin;
      }
    }

    _applyAmPmContext(low, hh, (v) => hh = v);

    mm ??= 0;
    hh = _clamp(hh, 0, 23);
    mm = _clamp(mm, 0, 59);
    return TimeParseResult(
      time: '${_pad2(hh)}:${_pad2(mm)}',
      match: m.group(0)!,
    );
  }

  return null;
}

bool _isTemporalWord(String w) => RegExp(
      r'^(hoje|amanha|depois|agora|cedo|tarde|noite|manha|madrugada|almoco)$',
    ).hasMatch(w);

/// Limpador de título semântico (versão robusta).
String cleanTitlePT(
  Object? raw, {
  bool hasTime = false,
  bool hasDate = false,
  bool titleCase = false,
}) {
  var text = (raw ?? '').toString();

  final origTokens = text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  final pairs = origTokens
      .map((orig) => (orig: orig, norm: normPT(orig)))
      .toList();

  const keepConnectors = {
    'de',
    'do',
    'da',
    'dos',
    'das',
    'com',
    'para',
    'pro',
    'pra',
    'no',
    'na',
    'nos',
    'nas',
    'du',
    'duma',
    'dum',
    'num',
    'numa',
  };

  bool contenty(String tNorm) =>
      RegExp(r'^[a-z0-9]+$').hasMatch(tNorm) &&
      tNorm.length >= 2 &&
      !_isTemporalWord(tNorm);

  var filtered = pairs;
  if (hasTime || hasDate) {
    filtered = filtered.where((p) => !_isTemporalWord(p.norm)).toList();
  }

  final kept = <String>[];
  for (var i = 0; i < filtered.length; i++) {
    final cur = filtered[i];
    final prev = i > 0 ? filtered[i - 1] : null;
    final next = i + 1 < filtered.length ? filtered[i + 1] : null;

    if (keepConnectors.contains(cur.norm)) {
      if (prev != null &&
          next != null &&
          contenty(prev.norm) &&
          contenty(next.norm)) {
        kept.add(cur.orig);
      }
      continue;
    }
    kept.add(cur.orig);
  }

  var out = kept.join(' ');

  out = out
      .replaceAll(RegExp(r'\bde\s+o\b', caseSensitive: false), 'do')
      .replaceAll(RegExp(r'\bde\s+a\b', caseSensitive: false), 'da')
      .replaceAll(RegExp(r'\bem\s+o\b', caseSensitive: false), 'no')
      .replaceAll(RegExp(r'\bem\s+a\b', caseSensitive: false), 'na')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (titleCase && out.isNotEmpty) {
    out = out[0].toUpperCase() + out.substring(1);
  }
  return out;
}

String smartTitleRepairPT([String raw = '']) {
  if (raw.isEmpty) return '';

  var t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();

  const fillersBeg =
      r'^(tipo|assim|entao|então|olha|veja|bom|ah|eh|é|aham|ai|aí|cara|mano|meu|minha|sei la|sei lá|entao tá|então tá|por favor,?)\b[\s,]*';
  const fillersEnd =
      r'[\s,]*(tipo|assim|né|tá|tá bom|tá bom\?|por favor)\s*$';

  t = t
      .replaceAll(RegExp(fillersBeg, caseSensitive: false), '')
      .replaceAll(RegExp(fillersEnd, caseSensitive: false), '');

  t = t
      .replaceAll(RegExp(r'\bp\/\b', caseSensitive: false), 'para')
      .replaceAll(RegExp(r'\bpra\b', caseSensitive: false), 'para')
      .replaceAll(RegExp(r'\bpro\b', caseSensitive: false), 'para o')
      .replaceAllMapped(RegExp(r'\bnuma?\b', caseSensitive: false), (m) {
        return m[0]!.toLowerCase() == 'numa' ? 'em uma' : 'em um';
      })
      .replaceAll(RegExp(r'\bq\b', caseSensitive: false), 'que')
      .replaceAll(RegExp(r'\bvc\b', caseSensitive: false), 'você')
      .replaceAll(RegExp(r'\btd\b', caseSensitive: false), 'tudo')
      .replaceAll(RegExp(r'\bblz\b', caseSensitive: false), 'beleza')
      .replaceAll(RegExp(r'\bpfv\b', caseSensitive: false), 'por favor');

  t = t.replaceAll(
    RegExp(
      r'^(?:eu\s+)?(?:preciso|precisava|precisarei|tenho\s+(?:que|de)|tem\s+(?:que|de)|devo|vou|queria|quero|gostaria\s+de|era\s+pra|é\s+pra|t[áa]\s+pra)\b[\s,]*',
      caseSensitive: false,
    ),
    '',
  );

  t = t.replaceAll(
    RegExp(
      r'^(?:fazer|ver|olhar|checar|arrumar|resolver)\b(?=\s*(?:isso|isso\s+a[ií]|a[ií]qui|ali|o\s+neg[oó]cio|uma?\s+coisa|as\s+coisas)?\s*[$,:-]?$)',
      caseSensitive: false,
    ),
    '',
  );

  const polite =
      r'(?:por\s+favor,?\s*|pode(?:ria)?\s+|consegue\s+|tem\s+como\s+|seria\s+possivel\s+|voce\s+pode\s+|vc\s+pode\s+)?';
  const pronPre = r'(?:me|te|nos|lhe|lhes)\s+';
  const pronPos = r'(?:\s*-(?:me|te|nos|lhe|lhes))?';
  const verbRem =
      r'(?:lembre|lembra|lembrar|recorde|recorda|recordar|avise|avisa|avisar|alerte|alerta|alertar|notifique|notifica|notificar)';

  t = t.replaceAll(
    RegExp(
      '^$polite(?:$pronPre)?(?:$verbRem)$pronPos\\s+(?:de|que)\\s+',
      caseSensitive: false,
    ),
    '',
  );
  t = t.replaceAll(
    RegExp(
      '\\b$polite(?:$pronPre)?(?:$verbRem)$pronPos\\s+(?:de|que)\\s+',
      caseSensitive: false,
    ),
    ' ',
  );

  t = t.replaceAll(
    RegExp(
      r'\b(?:pode(?:ria)?\s+)?(?:me\s+)?avis(?:ar|e|a)(?:-me)?\s+(?:quando|amanha|hoje|depois|mais\s+tarde|na?\s+(?:segunda|terca|terça|quarta|quinta|sexta|sabado|sábado|domingo)|as\s+\d{1,2}(?::\d{2})?)\b',
      caseSensitive: false,
    ),
    ' ',
  );

  t = t
      .replaceAll(
        RegExp(
          r'^(?:para|pra|p\/)\s*(?:eu|me)\s+lembrar\s+de\s+',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(
        RegExp(
          r'\b(?:para|pra|p\/)\s*(?:eu|me)\s+lembrar\s+de\s+',
          caseSensitive: false,
        ),
        ' ',
      );

  t = t
      .replaceAll(
        RegExp(
          r'^(?:por\s+favor,\s*)?nao\s+(?:me\s+)?deix[ea](?:\s+eu)?\s+esquecer\s+de\s+',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(
        RegExp(
          r'\bnao\s+(?:me\s+)?deix[ea](?:\s+eu)?\s+esquecer\s+de\s+',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(
        RegExp(
          r'^(?:para|pra|p\/)\s*(?:eu)?\s*nao\s+esquecer\s+de\s+',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(
        RegExp(
          r'\bque\s+(?:eu|a gente)\s+nao\s+esqueca\s+de\s+',
          caseSensitive: false,
        ),
        ' ',
      );

  t = t.replaceAll(
    RegExp(
      r'^(?:cria(?:r)?|crie|coloca(?:r)?|coloque|bota(?:r)?|bote|anota(?:r)?|anote|marca(?:r)?|marque|agenda(?:r)?|agende|registra(?:r)?|registre)\s+(?:um|uma)?\s*lembrete\s*(?:de|para|pra|p\/)\s*',
      caseSensitive: false,
    ),
    '',
  );

  t = t.replaceAll(
    RegExp(
      r'^(?:cria(?:r)?|crie|adiciona(?:r)?|adicione|coloca(?:r)?|coloque|bota(?:r)?|bote|anota(?:r)?|anote|marca(?:r)?|marque|registra(?:r)?|registre|define|defina|configura(?:r)?|configure)\s+(?:uma?\s+)?(?:tarefa|lembrete|anotacao|anotação|nota|evento)\s*(?:para|pra|p\/)?\s*',
      caseSensitive: false,
    ),
    '',
  );

  t = t.replaceAll(
    RegExp(
      r'^(?:e\s+)?(?:que\s+(?:eu|a gente|vou|iria|devo)\s+|que\s+)',
      caseSensitive: false,
    ),
    '',
  );

  t = t
      .replaceAll(
        RegExp(
          r'^(?:para|pra|p\/)\s*(?:me|te|nos|vos|lhe|lhes)?\s*lembrar\s+de\s+',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(
        RegExp(
          r'\b(?:para|pra|p\/)\s*(?:me|te|nos|vos|lhe|lhes)?\s*lembrar\s+de\s+',
          caseSensitive: false,
        ),
        ' ',
      );

  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

  t = t
      .replaceAll(RegExp(r'(\b\d{1,2})\s+oras?\b', caseSensitive: false), r'$1 horas')
      .replaceAll(
        RegExp(
          r'\b(as|às|a|da|de)\s+(\d{1,2})\s+oras?\b',
          caseSensitive: false,
        ),
        r'$1 $2 horas',
      )
      .replaceAll(
        RegExp(r'\b(\d{1,2})\s+ora(s?)\b', caseSensitive: false),
        r'$1 hora$2',
      )
      .replaceAll(
        RegExp(
          r'\bora(s?)\b(?=.*\b(\d{1,2}|manha|tarde|noite|am|pm)\b)',
          caseSensitive: false,
        ),
        r'hora$1',
      )
      .replaceAll(
        RegExp(
          r'(?<=\b(?:as|às|a|da|de)\s)\bora(s?)\b',
          caseSensitive: false,
        ),
        r'hora$1',
      );

  t = t
      .replaceAll(RegExp(r'\bmeio\s+dia\b', caseSensitive: false), 'meio-dia')
      .replaceAll(
        RegExp(r'\bmeia\s+noite\b', caseSensitive: false),
        'meia-noite',
      );

  t = t
      .replaceAll(RegExp(r'\bde\s+o\b', caseSensitive: false), 'do')
      .replaceAll(RegExp(r'\bde\s+a\b', caseSensitive: false), 'da')
      .replaceAll(RegExp(r'\bem\s+o\b', caseSensitive: false), 'no')
      .replaceAll(RegExp(r'\bem\s+a\b', caseSensitive: false), 'na');

  t = t.replaceAllMapped(
    RegExp(r'\b(\p{L}{2,})\b\s+\1\b', unicode: true, caseSensitive: false),
    (m) => m.group(1)!,
  );

  t = t
      .replaceAll(
        RegExp(r'\b(?:de|da|do|para|pra|p\/|em|no|na)\s*$', caseSensitive: false),
        '',
      )
      .trim();

  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

  return t;
}

String finalizeTitlePT([String raw = '']) {
  var t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();

  t = t
      .replaceAll(RegExp('^["\'\u201C\u201D\u201E\u00AB\u00BB]+'), '')
      .replaceAll(RegExp('["\'\u201C\u201D\u201E\u00AB\u00BB]+\$'), '')
      .trim();

  t = t
      .replaceAll(
        RegExp(
          r'^(?:e\s+)?(?:que\s+(?:eu|a gente|vou|iria|devo)\s+|que\s+)',
          caseSensitive: false,
        ),
        '',
      )
      .trim();

  t = t.replaceAll(RegExp(r'^e\s+', caseSensitive: false), '').trim();

  final mLembrar =
      RegExp(r'^(?:me\s+)?lembra\w*\s+(?:de\s+)(.+)$', caseSensitive: false)
          .firstMatch(t);
  if (mLembrar != null && mLembrar.group(1) != null) {
    t = mLembrar.group(1)!.trim();
  }

  final mQueEu = RegExp(
    r'^(?:que\s+(?:eu|a gente)\s+)?lembra\w*\s+de\s+(.+)$',
    caseSensitive: false,
  ).firstMatch(t);
  if (mQueEu != null && mQueEu.group(1) != null) {
    t = mQueEu.group(1)!.trim();
  }

  t = t.replaceAll(
    RegExp(r'\b(?:me\s+)?lembrar\w*\s+de\s+', caseSensitive: false),
    '',
  );

  t = t
      .replaceAll(
        RegExp(r'\b(?:de|da|do|para|pra|p\/)\s*$', caseSensitive: false),
        '',
      )
      .trim();

  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return _capFirst(t);
}

String stripTemporalResidualPT(String s) {
  if (s.isEmpty) return s;
  var t = ' $s ';

  t = t.replaceAll(
    RegExp(
      r'\b(?:ao|à|a|as|às)\s+(?:meio[-\s]dia|meia[-\s]noite)\b',
      caseSensitive: false,
    ),
    ' ',
  );

  t = t.replaceAll(
    RegExp(r'\b(?:meio[-\s]dia|meia[-\s]noite)\b', caseSensitive: false),
    ' ',
  );

  t = t.replaceAll(
    RegExp(
      r'\b(?:às|as|a|ao|à)\s*\d{1,2}(?:[:h]\d{2})?(?:\s*(?:horas?|h|hs))?\b',
      caseSensitive: false,
    ),
    ' ',
  );

  t = t.replaceAll(
    RegExp(
      r'\b\d{1,2}(?:[:h]\d{2})?\s*(?:horas?|h|hs)\b',
      caseSensitive: false,
    ),
    ' ',
  );

  t = t.replaceAll(RegExp(r'\bhoras?\b', caseSensitive: false), ' ');

  t = t.replaceAll(RegExp(r'\boras?\b', caseSensitive: false), ' ');

  t = t.replaceAll(RegExp(r'\b(?:às|as|a|ao|à)\b', caseSensitive: false), ' ');

  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

/// Extrai data (YYYY-MM-DD), hora (HH:mm) e um título limpo do transcript.
ExtractWhenResult extractWhenPTBR(String transcript, [DateTime? now]) {
  final ref = now ?? DateTime.now();
  final original = transcript.trim();
  final text = original;
  DateTime? date;
  String? time;
  final matches = <String>[];

  final exp = parseExplicitDate(text, ref);
  if (exp != null) {
    date = exp.date;
    matches.add(exp.match);
  }

  if (date == null) {
    final rel = parseRelativeDate(text, ref);
    if (rel != null) {
      date = rel.date;
      matches.add(rel.match);
    }
  }

  final tim = parseTime(text);
  if (tim != null) {
    time = tim.time;
    matches.add(tim.match);
  }

  if (time == null) {
    final inferred = inferTimeByContext(text, ref);
    if (inferred != null) {
      time = inferred.time;
      matches.add(inferred.match);
    }
  }

  var titleSource = text;

  for (final m in matches) {
    if (m.isEmpty) continue;
    titleSource = _removeAccentInsensitive(titleSource, m);
  }

  titleSource = titleSource.replaceAll(RegExp(r'\s+'), ' ').trim();

  titleSource = stripTemporalResidualPT(titleSource);

  final cleaned = cleanTitlePT(
    titleSource,
    hasTime: time != null,
    hasDate: date != null,
    titleCase: false,
  );

  final finalTitle = finalizeTitlePT(
    smartTitleRepairPT(cleaned.isNotEmpty ? cleaned : original),
  );

  return ExtractWhenResult(
    title: finalTitle,
    dateYmd: date != null ? _toYMD(date) : null,
    timeHHMM: time,
  );
}

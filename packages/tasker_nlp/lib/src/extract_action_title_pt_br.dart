import 'extract_place_pt_br.dart';
import 'extract_when_pt_br.dart';

const _actionVerbs = {
  'comprar',
  'pegar',
  'buscar',
  'levantar',
  'retirar',
  'pagar',
  'levar',
  'enviar',
  'mandar',
  'fazer',
  'trocar',
  'devolver',
  'reservar',
  'encomendar',
  'pedir',
};

/// Extrai título curto com a ação principal («Comprar pão») sem local nem horário.
String? extractCoreActionTitlePTBR(
  String transcript, {
  ExtractPlaceResult? place,
}) {
  var core = transcript.trim();
  if (core.isEmpty) return null;

  core = stripPeriodTimePhrasesPT(core);
  core = stripSpokenTimePhrasesPT(core);
  core = stripTemporalResidualPT(core);

  if (place != null) {
    core = stripPlaceFromTitle(core, place);
  } else {
    core = _stripTrailingPlaceClause(core);
  }

  core = core.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (core.isEmpty) return null;

  final low = normPT(core);
  final verbMatch = RegExp(
    r'\b(comprar|pegar|buscar|levantar|retirar|pagar|levar|enviar|mandar|'
    r'fazer|trocar|devolver|reservar|encomendar|pedir)\b',
    caseSensitive: false,
  ).firstMatch(low);
  if (verbMatch == null) return null;

  final start = verbMatch.start;
  var action = core.substring(start).trim();
  action = stripPeriodTimePhrasesPT(action);
  action = stripTemporalResidualPT(action);
  action = action.replaceAll(RegExp(r'\s+'), ' ').trim();

  if (action.isEmpty) return null;

  final tokens = normPT(action).split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  if (tokens.length > 8) return null;

  return finalizeTitlePT(smartTitleRepairPT(action));
}

String _stripTrailingPlaceClause(String text) {
  var t = text;
  t = t.replaceFirst(
    RegExp(
      r'\s+(?:na|no|nem|em|ao|à|aos|nas|nos)\s+[\p{L}\p{N}][\p{L}\p{N}\s\-\.]{1,40}'
      r'(?:\s+(?:no|na|em)\s+(?:inicio|comeco|fim|principio)\s+(?:da|de|do)\s+'
      r'(?:manha|tarde|noite))?.*$',
      unicode: true,
      caseSensitive: false,
    ),
    '',
  );
  return t.trim();
}

/// Indica compra/recado simples (ex.: comprar pão) — não serviços como levar pet.
bool looksLikeSingleErrandAction(String transcript) {
  final low = normPT(transcript);
  if (!RegExp(r'\b(?:comprar|pegar|buscar|levantar|retirar)\b').hasMatch(low)) {
    return false;
  }
  return !RegExp(r',\s*|\be\s+(?:comprar|pegar|buscar|pagar)\b').hasMatch(low);
}

bool isErrandActionVerb(String word) => _actionVerbs.contains(normPT(word));

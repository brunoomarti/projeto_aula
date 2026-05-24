import 'dart:math' as math;

/// Acumula segmentos de fala — evita apagar texto após pausas do ASR.
class TranscriptAccumulator {
  String _committed = '';
  String _segment = '';

  void reset() {
    _committed = '';
    _segment = '';
  }

  String get text {
    final c = _committed.trim();
    final s = _segment.trim();
    if (c.isEmpty) return s;
    if (s.isEmpty) return c;
    return _mergeFinal(c, s);
  }

  void apply(String words, {bool isFinal = false}) {
    final w = words.trim();
    if (w.isEmpty) return;

    if (isFinal) {
      _committed = _mergeFinal(_committed, w);
      _segment = '';
      return;
    }

  // Novo segmento após pausa do ASR — commita o anterior antes de substituir.
    if (_segment.isNotEmpty && !_isContinuation(_segment, w)) {
      _committed = _mergeFinal(_committed, _segment);
      _segment = '';
    }

    _segment = w;
  }

  void flush() {
    if (_segment.isEmpty) return;
    _committed = _mergeFinal(_committed, _segment);
    _segment = '';
  }

  /// Mescla texto já confirmado com novo trecho, evitando repetição.
  static String _mergeFinal(String committed, String incoming) {
    final c = committed.trim();
    final i = incoming.trim();
    if (i.isEmpty) return c;
    if (c.isEmpty) return i;

    final cl = c.toLowerCase();
    final il = i.toLowerCase();

    if (cl == il) return c;
    if (il.startsWith(cl)) return i;
    if (cl.startsWith(il)) return c;
    if (cl.endsWith(il)) return c;

    final overlap = _wordOverlapSuffixPrefix(c, i);
    if (overlap > 0) {
      final iWords = i.split(RegExp(r'\s+'));
      return '$c ${iWords.sublist(overlap).join(' ')}'.trim();
    }

    return '$c $i';
  }

  static int _wordOverlapSuffixPrefix(String left, String right) {
    final lw = left.split(RegExp(r'\s+'));
    final rw = right.split(RegExp(r'\s+'));
    final max = math.min(lw.length, rw.length);
    for (var size = max; size > 0; size--) {
      var matches = true;
      for (var i = 0; i < size; i++) {
        if (lw[lw.length - size + i].toLowerCase() !=
            rw[i].toLowerCase()) {
          matches = false;
          break;
        }
      }
      if (matches) return size;
    }
    return 0;
  }

  static bool _isContinuation(String prev, String next) {
    final p = prev.trim().toLowerCase();
    final n = next.trim().toLowerCase();
    if (p.isEmpty || n.isEmpty) return true;
    if (n.startsWith(p) || p.startsWith(n)) return true;

    final pw = p.split(RegExp(r'\s+'));
    final nw = n.split(RegExp(r'\s+'));
    if (pw.isNotEmpty && nw.isNotEmpty && pw.first == nw.first) return true;
    if (pw.length >= 2 &&
        nw.length >= 2 &&
        pw[0] == nw[0] &&
        pw[1] == nw[1]) {
      return true;
    }

    final maxCommon = math.min(p.length, n.length);
    var common = 0;
    for (var i = 0; i < maxCommon; i++) {
      if (p[i] != n[i]) break;
      common++;
    }
    return common >= 4;
  }
}

/// Alterna o parser do [MagicTaskInput] entre NLP local e Gemini.
abstract final class MagicInputParserConfig {
  /// `true` → Gemini interpreta a frase + refinamento leve com NLP local.
  /// `false` → somente NLP local (padrão).
  static const bool useGeminiParser = true;

  /// Modelo Gemini usado nos testes híbridos.
  static const String geminiModel = 'gemini-2.5-flash';
}

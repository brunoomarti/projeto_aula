/// Configuração do placeholder animado do [MagicTaskInput].
abstract final class MagicInputPlaceholderConfig {
  /// `true` → animação caractere a caractere (legado; mais rebuilds).
  /// `false` → troca de frase com fade a cada [fadeCycleInterval].
  static const bool useTypingAnimation = false;

  /// Intervalo entre trocas de frase no modo fade.
  static const Duration fadeCycleInterval = Duration(seconds: 4);

  /// Duração do fade out / fade in.
  static const Duration fadeDuration = Duration(milliseconds: 220);
}

/// Chaves de ícone e cores ARGB usadas pelo NLP (espelham o catálogo do app).
abstract final class NlpIconPalette {
  static const defaultIconKey = 'home';

  static const defaultBackgroundArgb = 0xFFD4CCFF;

  /// Mesmas 12 cores de fundo do [TaskIconCatalog] do app.
  static const List<int> backgroundArgbs = [
    0xFFD4CCFF,
    0xFFB8F0D0,
    0xFFD4F5A8,
    0xFFFFF0A8,
    0xFFFFD4CC,
    0xFFB8E4FF,
    0xFFFFE0C8,
    0xFFFFCCE8,
    0xFFB8F0F0,
    0xFFFFDAB8,
    0xFFC8CCFF,
    0xFFD8DCE8,
  ];

  static const List<String> iconKeys = [
    'home',
    'gym',
    'ball_sports',
    'swimming',
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
    'leisure',
    'repair',
    'clothing',
    'beauty',
    'faith',
    'task',
  ];

  static bool isValidIconKey(String key) => iconKeys.contains(key);

  static int backgroundArgbForIconKey(String iconKey) {
    for (var i = 0; i < iconKeys.length; i++) {
      if (iconKeys[i] == iconKey && i < backgroundArgbs.length) {
        return backgroundArgbs[i];
      }
    }
    return defaultBackgroundArgb;
  }
}

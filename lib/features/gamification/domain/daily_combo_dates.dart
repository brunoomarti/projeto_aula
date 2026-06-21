/// Utilitários de data para o combo diário.
abstract final class DailyComboDates {
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String formatYmd(DateTime date) {
    final d = dateOnly(date);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime? parseYmd(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}

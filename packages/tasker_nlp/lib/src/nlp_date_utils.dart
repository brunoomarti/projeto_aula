/// Utilitários de data usados pelo NLP (sem depender do app).
String formatDateYmd(DateTime date) {
  return '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Calcula la próxima fecha de un pago recurrente.
///
/// En meses cortos el día se ajusta al final del mes (ej. 31 ene → 28 feb).
DateTime advanceDueDate(DateTime date, String frequency) {
  switch (frequency) {
    case 'weekly':
      return date.add(const Duration(days: 7));
    case 'yearly':
      final lastDay = DateTime(date.year + 1, date.month + 1, 0).day;
      return DateTime(date.year + 1, date.month, date.day.clamp(1, lastDay));
    case 'monthly':
    default:
      final lastDay = DateTime(date.year, date.month + 2, 0).day;
      return DateTime(date.year, date.month + 1, date.day.clamp(1, lastDay));
  }
}

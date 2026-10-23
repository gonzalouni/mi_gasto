import 'package:flutter_test/flutter_test.dart';
import 'package:mi_gasto/models/recurring.dart';
import 'package:mi_gasto/utils/recurrence.dart';

void main() {
  test('advanceDueDate semanal suma 7 días', () {
    expect(advanceDueDate(DateTime(2026, 10, 20), 'weekly'),
        DateTime(2026, 10, 27));
  });

  test('advanceDueDate mensual mantiene el día del mes', () {
    expect(advanceDueDate(DateTime(2026, 10, 15), 'monthly'),
        DateTime(2026, 11, 15));
  });

  test('advanceDueDate mensual ajusta días que no existen en el mes corto', () {
    expect(advanceDueDate(DateTime(2026, 1, 31), 'monthly'),
        DateTime(2026, 2, 28));
  });

  test('advanceDueDate anual ajusta el 29 de febrero', () {
    expect(advanceDueDate(DateTime(2024, 2, 29), 'yearly'),
        DateTime(2025, 2, 28));
  });

  test('RecurringRule serializa y deserializa sin perder datos', () {
    final rule = RecurringRule(
      id: 'r1',
      type: 'expense',
      amount: 1200,
      accountId: 'acc_1',
      categoryId: 'cat_hogar',
      note: 'Alquiler',
      frequency: 'monthly',
      nextDue: DateTime(2026, 11, 1),
    );

    final restored = RecurringRule.fromMap(rule.toMap());

    expect(restored.id, rule.id);
    expect(restored.type, rule.type);
    expect(restored.amount, rule.amount);
    expect(restored.accountId, rule.accountId);
    expect(restored.categoryId, rule.categoryId);
    expect(restored.note, rule.note);
    expect(restored.frequency, rule.frequency);
    expect(restored.nextDue, rule.nextDue);
    expect(restored.active, isTrue);
    expect(restored.copyWith(nextDue: DateTime(2026, 12, 1)).nextDue,
        DateTime(2026, 12, 1));
  });
}

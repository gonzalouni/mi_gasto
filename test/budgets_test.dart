import 'package:flutter_test/flutter_test.dart';
import 'package:mi_gasto/models/budget.dart';
import 'package:mi_gasto/models/transaction.dart';
import 'package:mi_gasto/utils/calculations.dart';

AppTransaction _expense({
  required String id,
  required double amount,
  String categoryId = 'cat_1',
  DateTime? date,
}) =>
    AppTransaction(
      id: id,
      type: 'expense',
      amount: amount,
      accountId: 'acc_1',
      categoryId: categoryId,
      date: date ?? DateTime(2026, 10, 20),
      note: '',
      createdAt: DateTime(2026, 10, 20),
    );

void main() {
  test('el periodo empieza el día de pago', () {
    expect(budgetPeriodStart(DateTime(2026, 10, 20), 15), DateTime(2026, 10, 15));
    expect(budgetPeriodEnd(DateTime(2026, 10, 20), 15), DateTime(2026, 11, 15));
  });

  test('antes del día de pago el periodo es del mes anterior', () {
    expect(budgetPeriodStart(DateTime(2026, 10, 10), 15), DateTime(2026, 9, 15));
    expect(budgetPeriodEnd(DateTime(2026, 10, 10), 15), DateTime(2026, 10, 15));
  });

  test('con día de pago 1 el periodo es el mes calendario', () {
    expect(budgetPeriodStart(DateTime(2026, 10, 20), 1), DateTime(2026, 10, 1));
    expect(budgetPeriodEnd(DateTime(2026, 10, 20), 1), DateTime(2026, 11, 1));
  });

  test('spentInPeriod solo cuenta gastos dentro del rango', () {
    final transactions = [
      _expense(id: 'e1', amount: 30, date: DateTime(2026, 10, 15)),
      _expense(
          id: 'e2',
          amount: 20,
          date: DateTime(2026, 10, 20),
          categoryId: 'cat_2'),
      _expense(id: 'e3', amount: 99, date: DateTime(2026, 10, 14)),
      AppTransaction(
        id: 'i1',
        type: 'income',
        amount: 500,
        accountId: 'acc_1',
        categoryId: 'cat_2',
        date: DateTime(2026, 10, 16),
        note: '',
        createdAt: DateTime(2026, 10, 16),
      ),
      AppTransaction(
        id: 't1',
        type: 'transfer',
        amount: 80,
        accountId: 'acc_1',
        categoryId: 'cat_transferencia',
        date: DateTime(2026, 10, 17),
        note: '',
        createdAt: DateTime(2026, 10, 17),
        toAccountId: 'acc_2',
      ),
    ];

    expect(
      spentInPeriod(transactions,
          start: DateTime(2026, 10, 15), end: DateTime(2026, 11, 15)),
      50,
    );
    expect(
      spentInPeriod(transactions,
          start: DateTime(2026, 10, 15),
          end: DateTime(2026, 11, 15),
          categoryId: 'cat_2'),
      20,
    );
  });

  test('budgetStatus calcula ritmo y proyección', () {
    final transactions = [
      _expense(id: 'e1', amount: 60, date: DateTime(2026, 10, 16))
    ];
    final status = budgetStatus(
      transactions: transactions,
      categoryId: 'cat_1',
      amount: 300,
      start: DateTime(2026, 10, 15),
      end: DateTime(2026, 11, 14),
      now: DateTime(2026, 10, 29),
    );

    expect(status.spent, 60);
    expect(status.ratio, closeTo(0.2, 0.001));
    expect(status.elapsedDays, 15);
    expect(status.totalDays, 30);
    expect(status.expectedByNow, 150);
    expect(status.projectedTotal, 120);
    expect(status.isOverBudget, isFalse);
    expect(status.isOverPace, isFalse);
    expect(status.reached80, isFalse);
  });

  test('budgetStatus marca alertas al 80% y sobre el ritmo', () {
    final transactions = [
      _expense(id: 'e1', amount: 260, date: DateTime(2026, 10, 16))
    ];
    final status = budgetStatus(
      transactions: transactions,
      categoryId: kTotalBudgetCategoryId,
      amount: 300,
      start: DateTime(2026, 10, 15),
      end: DateTime(2026, 11, 14),
      now: DateTime(2026, 10, 20),
    );

    expect(status.reached80, isTrue);
    expect(status.isOverBudget, isFalse);
    expect(status.isOverPace, isTrue);
  });

  test('budgetCrossingAlerts avisa al cruzar el 80%', () {
    final before = [_expense(id: 'e1', amount: 100)];
    final after = [...before, _expense(id: 'e2', amount: 150)];

    final alerts = budgetCrossingAlerts(
      budgets: const [
        Budget(id: 'b1', categoryId: 'cat_1', amount: 300),
      ],
      before: before,
      after: after,
      categoryId: 'cat_1',
      now: DateTime(2026, 10, 20),
      payDay: 1,
    );

    expect(alerts, hasLength(1));
    expect(alerts.first.exceeded, isFalse);
    expect(alerts.first.ratio, closeTo(0.833, 0.001));
  });

  test('budgetCrossingAlerts avisa al superar el 100%', () {
    final before = [_expense(id: 'e1', amount: 280)];
    final after = [...before, _expense(id: 'e2', amount: 50)];

    final alerts = budgetCrossingAlerts(
      budgets: const [
        Budget(id: 'b1', categoryId: 'cat_1', amount: 300),
      ],
      before: before,
      after: after,
      categoryId: 'cat_1',
      now: DateTime(2026, 10, 20),
      payDay: 1,
    );

    expect(alerts, hasLength(1));
    expect(alerts.first.exceeded, isTrue);
  });

  test('budgetCrossingAlerts no avisa si ya estaba cruzado o no aplica', () {
    final before = [_expense(id: 'e1', amount: 350)];
    final after = [...before, _expense(id: 'e2', amount: 20)];

    // Ya estaba superado antes: no vuelve a avisar.
    final sameBudget = budgetCrossingAlerts(
      budgets: const [
        Budget(id: 'b1', categoryId: 'cat_1', amount: 300),
      ],
      before: before,
      after: after,
      categoryId: 'cat_1',
      now: DateTime(2026, 10, 20),
      payDay: 1,
    );
    expect(sameBudget, isEmpty);

    // Presupuesto de otra categoría: no aplica.
    final otherCategory = budgetCrossingAlerts(
      budgets: const [
        Budget(id: 'b2', categoryId: 'cat_2', amount: 300),
      ],
      before: before,
      after: after,
      categoryId: 'cat_1',
      now: DateTime(2026, 10, 20),
      payDay: 1,
    );
    expect(otherCategory, isEmpty);
  });

  test('Budget serializa y deserializa sin perder datos', () {
    const budget = Budget(id: 'b1', categoryId: 'cat_1', amount: 250);

    final restored = Budget.fromMap(budget.toMap());

    expect(restored.id, budget.id);
    expect(restored.categoryId, budget.categoryId);
    expect(restored.amount, budget.amount);
    expect(restored.isTotal, isFalse);

    const total = Budget(
        id: 'b2', categoryId: kTotalBudgetCategoryId, amount: 1000);
    expect(Budget.fromMap(total.toMap()).isTotal, isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_gasto/models/account.dart';
import 'package:mi_gasto/models/transaction.dart';
import 'package:mi_gasto/utils/calculations.dart';

AppTransaction _tx({
  required String id,
  required String type,
  required double amount,
  String accountId = 'acc_1',
  String categoryId = 'cat_1',
  DateTime? date,
  String? toAccountId,
}) =>
    AppTransaction(
      id: id,
      type: type,
      amount: amount,
      accountId: accountId,
      categoryId: categoryId,
      date: date ?? DateTime(2026, 10, 10),
      note: '',
      createdAt: DateTime(2026, 10, 10),
      toAccountId: toAccountId,
    );

void main() {
  final transactions = [
    _tx(id: 't1', type: 'expense', amount: 30, categoryId: 'cat_comida'),
    _tx(id: 't2', type: 'expense', amount: 20, categoryId: 'cat_comida'),
    _tx(id: 't3', type: 'expense', amount: 50, categoryId: 'cat_transporte'),
    _tx(id: 't4', type: 'income', amount: 100, categoryId: 'cat_sueldo'),
    _tx(
        id: 't5',
        type: 'expense',
        amount: 10,
        date: DateTime(2026, 9, 30)),
  ];

  test('summarize calcula ingresos, gastos y balance', () {
    final summary = summarize(transactions);

    expect(summary.income, 100);
    expect(summary.expense, 110);
    expect(summary.balance, -10);
  });

  test('filterByMonth filtra por mes y año', () {
    final october = filterByMonth(transactions, DateTime(2026, 10));

    expect(october.length, 4);
    expect(filterByMonth(transactions, DateTime(2026, 9)).length, 1);
    expect(filterByMonth(transactions, DateTime(2025, 10)), isEmpty);
  });

  test('totalsByCategory suma solo del tipo pedido', () {
    final byCategory = totalsByCategory(transactions, type: 'expense');

    expect(byCategory['cat_comida'], 50);
    expect(byCategory['cat_transporte'], 50);
    expect(byCategory.containsKey('cat_sueldo'), isFalse);
  });

  test('totalsByDay agrupa por día del mes', () {
    final byDay = totalsByDay(transactions, type: 'expense');

    expect(byDay[10], 100);
    expect(byDay[30], 10);
    expect(byDay[15], isNull);
  });

  test('accountBalance suma ingresos y resta gastos desde el saldo inicial', () {
    const account = Account(
      id: 'acc_1',
      name: 'Banco',
      type: 'bank',
      initialBalance: 200,
      currency: 'PEN',
    );

    expect(accountBalance(account, transactions), 190);
  });

  test('balancesByAccount calcula saldo por cuenta', () {
    const accounts = [
      Account(
        id: 'acc_1',
        name: 'Banco',
        type: 'bank',
        initialBalance: 0,
        currency: 'PEN',
      ),
      Account(
        id: 'acc_2',
        name: 'Efectivo',
        type: 'cash',
        initialBalance: 500,
        currency: 'PEN',
      ),
    ];

    final balances = balancesByAccount(accounts, transactions);

    expect(balances['acc_1'], -10);
    expect(balances['acc_2'], 500);
  });

  test('monthlyTotals ordena y suma por mes los últimos N meses', () {
    final transactions = [
      _tx(
          id: 'e1',
          type: 'expense',
          amount: 100,
          date: DateTime(2026, 8, 10)),
      _tx(
          id: 'e2',
          type: 'expense',
          amount: 50,
          date: DateTime(2026, 9, 5)),
      _tx(
          id: 'e3',
          type: 'expense',
          amount: 30,
          date: DateTime(2026, 9, 20)),
      _tx(
          id: 'e4',
          type: 'expense',
          amount: 70,
          date: DateTime(2026, 10, 1)),
      _tx(
          id: 'i1',
          type: 'income',
          amount: 999,
          date: DateTime(2026, 10, 1)),
    ];

    final totals = monthlyTotals(transactions,
        type: 'expense', lastMonth: DateTime(2026, 10), months: 4);

    expect(totals, hasLength(4));
    expect(totals.map((t) => t.month), [
      DateTime(2026, 7),
      DateTime(2026, 8),
      DateTime(2026, 9),
      DateTime(2026, 10),
    ]);
    expect(totals[0].total, 0);
    expect(totals[1].total, 100);
    expect(totals[2].total, 80);
    expect(totals[3].total, 70);
  });

  test('savingsRate calcula el porcentaje ahorrado', () {
    expect(savingsRate(income: 1000, expense: 400), closeTo(0.6, 0.001));
    expect(savingsRate(income: 1000, expense: 1000), 0);
    expect(savingsRate(income: 0, expense: 100), 0);
  });

  test('dailyAverage reparte el gasto entre los días', () {
    expect(dailyAverage(expense: 300, days: 30), 10);
    expect(dailyAverage(expense: 300, days: 0), 0);
  });

  test('las transferencias no cuentan como ingreso ni gasto', () {
    final transfers = [
      _tx(
        id: 't1',
        type: 'transfer',
        amount: 40,
        accountId: 'acc_1',
        toAccountId: 'acc_2',
      ),
    ];

    final summary = summarize(transfers);

    expect(summary.income, 0);
    expect(summary.expense, 0);
    expect(summary.balance, 0);
  });

  test('una transferencia resta en la cuenta origen y suma en la destino', () {
    const origen = Account(
      id: 'acc_1',
      name: 'Banco',
      type: 'bank',
      initialBalance: 100,
      currency: 'PEN',
    );
    const destino = Account(
      id: 'acc_2',
      name: 'Efectivo',
      type: 'cash',
      initialBalance: 50,
      currency: 'PEN',
    );
    final transfers = [
      _tx(
        id: 't1',
        type: 'transfer',
        amount: 30,
        accountId: 'acc_1',
        toAccountId: 'acc_2',
      ),
    ];

    expect(accountBalance(origen, transfers), 70);
    expect(accountBalance(destino, transfers), 80);
  });
}

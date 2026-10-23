import 'package:flutter_test/flutter_test.dart';
import 'package:mi_gasto/models/account.dart';
import 'package:mi_gasto/models/category.dart';
import 'package:mi_gasto/models/transaction.dart';

void main() {
  test('Account serializa y deserializa sin perder datos', () {
    const account = Account(
      id: 'acc_1',
      name: 'Banco',
      type: 'bank',
      initialBalance: 150.5,
      currency: 'PEN',
    );

    final restored = Account.fromMap(account.toMap());

    expect(restored.id, account.id);
    expect(restored.name, account.name);
    expect(restored.type, account.type);
    expect(restored.initialBalance, account.initialBalance);
    expect(restored.currency, account.currency);
  });

  test('TxCategory serializa y deserializa sin perder datos', () {
    const category = TxCategory(
      id: 'cat_1',
      name: 'Comida',
      icon: 'foodTray',
      color: 0xFFE57373,
      type: 'expense',
    );

    final restored = TxCategory.fromMap(category.toMap());

    expect(restored.id, category.id);
    expect(restored.name, category.name);
    expect(restored.icon, category.icon);
    expect(restored.color, category.color);
    expect(restored.type, category.type);
  });

  test('AppTransaction serializa y deserializa sin perder datos', () {
    final transaction = AppTransaction(
      id: 'tx_1',
      type: 'expense',
      amount: 25.4,
      accountId: 'acc_1',
      categoryId: 'cat_1',
      date: DateTime(2026, 10, 15, 14, 30),
      note: 'Almuerzo',
      createdAt: DateTime(2026, 10, 15, 14, 31),
      toAccountId: 'acc_2',
    );

    final restored = AppTransaction.fromMap(transaction.toMap());

    expect(restored.id, transaction.id);
    expect(restored.type, transaction.type);
    expect(restored.amount, transaction.amount);
    expect(restored.accountId, transaction.accountId);
    expect(restored.categoryId, transaction.categoryId);
    expect(restored.date, transaction.date);
    expect(restored.note, transaction.note);
    expect(restored.createdAt, transaction.createdAt);
    expect(restored.toAccountId, transaction.toAccountId);
    expect(restored.type, 'expense');
    expect(restored.isIncome, isFalse);
    expect(restored.isTransfer, isFalse);
  });

  test('AppTransaction acepta montos enteros llegados como int (JSON)', () {
    final restored = AppTransaction.fromMap({
      'id': 'tx_2',
      'type': 'income',
      'amount': 100,
      'account_id': 'acc_1',
      'category_id': 'cat_1',
      'date': 0,
      'note': '',
      'created_at': 0,
    });

    expect(restored.amount, 100.0);
    expect(restored.isIncome, isTrue);
  });
}

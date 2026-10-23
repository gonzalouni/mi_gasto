class AppTransaction {
  const AppTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    required this.categoryId,
    required this.date,
    required this.note,
    required this.createdAt,
    this.toAccountId,
  });

  final String id;
  final String type;
  final double amount;
  final String accountId;
  final String categoryId;
  final DateTime date;
  final String note;
  final DateTime createdAt;

  // Solo se usa cuando el movimiento es una transferencia entre cuentas.
  final String? toAccountId;

  bool get isIncome => type == 'income';

  bool get isTransfer => type == 'transfer';

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'account_id': accountId,
        'category_id': categoryId,
        // Se guardan como millis para ordenar y filtrar por rango en SQL.
        'date': date.millisecondsSinceEpoch,
        'note': note,
        'created_at': createdAt.millisecondsSinceEpoch,
        'to_account_id': toAccountId,
      };

  factory AppTransaction.fromMap(Map<String, dynamic> map) => AppTransaction(
        id: map['id'] as String,
        type: map['type'] as String,
        amount: (map['amount'] as num).toDouble(),
        accountId: map['account_id'] as String,
        categoryId: map['category_id'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        note: map['note'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        toAccountId: map['to_account_id'] as String?,
      );
}

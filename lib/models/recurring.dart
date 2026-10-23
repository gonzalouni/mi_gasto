class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    required this.categoryId,
    required this.note,
    required this.frequency,
    required this.nextDue,
    this.active = true,
  });

  final String id;
  final String type; // 'expense' | 'income'
  final double amount;
  final String accountId;
  final String categoryId;
  final String note;
  final String frequency; // 'weekly' | 'monthly' | 'yearly'
  final DateTime nextDue;
  final bool active;

  RecurringRule copyWith({DateTime? nextDue}) => RecurringRule(
        id: id,
        type: type,
        amount: amount,
        accountId: accountId,
        categoryId: categoryId,
        note: note,
        frequency: frequency,
        nextDue: nextDue ?? this.nextDue,
        active: active,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'account_id': accountId,
        'category_id': categoryId,
        'note': note,
        'frequency': frequency,
        'next_due': nextDue.millisecondsSinceEpoch,
        'active': active ? 1 : 0,
      };

  factory RecurringRule.fromMap(Map<String, dynamic> map) => RecurringRule(
        id: map['id'] as String,
        type: map['type'] as String,
        amount: (map['amount'] as num).toDouble(),
        accountId: map['account_id'] as String,
        categoryId: map['category_id'] as String,
        note: map['note'] as String? ?? '',
        frequency: map['frequency'] as String,
        nextDue: DateTime.fromMillisecondsSinceEpoch(map['next_due'] as int),
        active: (map['active'] as int? ?? 1) == 1,
      );
}

const Map<String, String> kFrequencyLabels = {
  'weekly': 'Semanal',
  'monthly': 'Mensual',
  'yearly': 'Anual',
};

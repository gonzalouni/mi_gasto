const String kTotalBudgetCategoryId = 'total';

class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.amount,
  });

  final String id;

  // 'total' para el presupuesto global; si no, el id de la categoría.
  final String categoryId;
  final double amount;

  bool get isTotal => categoryId == kTotalBudgetCategoryId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'category_id': categoryId,
        'amount': amount,
      };

  factory Budget.fromMap(Map<String, dynamic> map) => Budget(
        id: map['id'] as String,
        categoryId: map['category_id'] as String,
        amount: (map['amount'] as num).toDouble(),
      );
}

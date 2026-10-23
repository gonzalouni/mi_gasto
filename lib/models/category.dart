class TxCategory {
  const TxCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
  });

  final String id;
  final String name;
  final String icon;
  final int color;
  final String type;

  bool get isExpense => type == 'expense';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'type': type,
      };

  factory TxCategory.fromMap(Map<String, dynamic> map) => TxCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        icon: map['icon'] as String,
        color: map['color'] as int,
        type: map['type'] as String,
      );
}

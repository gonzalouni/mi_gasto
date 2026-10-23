class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.currency,
  });

  final String id;
  final String name;
  final String type;
  final double initialBalance;
  final String currency;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'initial_balance': initialBalance,
        'currency': currency,
      };

  factory Account.fromMap(Map<String, dynamic> map) => Account(
        id: map['id'] as String,
        name: map['name'] as String,
        type: map['type'] as String,
        initialBalance: (map['initial_balance'] as num).toDouble(),
        currency: map['currency'] as String,
      );
}

const Map<String, String> kAccountTypeLabels = {
  'cash': 'Efectivo',
  'bank': 'Banco',
  'wallet': 'Billetera digital',
  'savings': 'Ahorro',
  'credit': 'Tarjeta de crédito',
  'investment': 'Inversión',
};

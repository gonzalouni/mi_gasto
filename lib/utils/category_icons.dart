import 'package:reicon_flutter/reicon_flutter.dart';

String? iconPathForName(String name) => Reicon.outline[name];

const Map<String, String> kAccountIconNames = {
  'cash': 'moneyBill',
  'bank': 'bank',
  'wallet': 'wallet',
  'savings': 'moneyBag',
  'credit': 'card',
  'investment': 'trendUp',
};

String accountIconName(String type) => kAccountIconNames[type] ?? 'wallet';

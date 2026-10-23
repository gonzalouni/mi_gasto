import 'package:intl/intl.dart';

const Map<String, String> kCurrencySymbols = {
  'PEN': 'S/',
  'USD': r'$',
  'EUR': '€',
};

String formatMoney(double amount, String currency) {
  final symbol = kCurrencySymbols[currency] ?? '$currency ';
  return NumberFormat.currency(
    locale: 'es_PE',
    symbol: symbol,
    decimalDigits: 2,
  ).format(amount);
}

String formatDate(DateTime date, String pattern) =>
    DateFormat(pattern, 'es_PE').format(date);

String capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/transaction.dart';
import '../utils/calculations.dart';

class TransactionsProvider extends ChangeNotifier {
  List<AppTransaction> _transactions = [];
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime get selectedMonth => _selectedMonth;

  List<AppTransaction> get all => _transactions;

  List<AppTransaction> get monthTransactions {
    final list = filterByMonth(_transactions, _selectedMonth);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  MonthSummary get summary => summarize(monthTransactions);

  Map<String, double> get expenseByCategory =>
      totalsByCategory(monthTransactions, type: 'expense');

  Map<int, double> get expenseByDay =>
      totalsByDay(monthTransactions, type: 'expense');

  Future<void> load() async {
    _transactions = await DatabaseHelper.instance.getTransactions();
    notifyListeners();
  }

  void selectMonth(DateTime month) {
    _selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  Future<void> add(AppTransaction transaction) async {
    await DatabaseHelper.instance.insertTransaction(transaction);
    await load();
  }

  Future<void> update(AppTransaction transaction) async {
    await DatabaseHelper.instance.updateTransaction(transaction);
    await load();
  }

  Future<void> remove(String id) async {
    await DatabaseHelper.instance.deleteTransaction(id);
    await load();
  }
}

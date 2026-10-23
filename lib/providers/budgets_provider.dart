import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/budget.dart';

class BudgetsProvider extends ChangeNotifier {
  List<Budget> budgets = [];

  Future<void> load() async {
    budgets = await DatabaseHelper.instance.getBudgets();
    notifyListeners();
  }

  Budget? byCategoryId(String categoryId) {
    for (final budget in budgets) {
      if (budget.categoryId == categoryId) return budget;
    }
    return null;
  }

  Future<void> add(Budget budget) async {
    await DatabaseHelper.instance.insertBudget(budget);
    await load();
  }

  Future<void> update(Budget budget) async {
    await DatabaseHelper.instance.updateBudget(budget);
    await load();
  }

  Future<void> remove(String id) async {
    await DatabaseHelper.instance.deleteBudget(id);
    await load();
  }
}

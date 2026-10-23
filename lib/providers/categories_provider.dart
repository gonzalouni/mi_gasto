import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/category.dart';

class CategoriesProvider extends ChangeNotifier {
  List<TxCategory> categories = [];

  Future<void> load() async {
    categories = await DatabaseHelper.instance.getCategories();
    notifyListeners();
  }

  List<TxCategory> byType(String type) =>
      categories.where((c) => c.type == type).toList();

  TxCategory? byId(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  Future<void> add(TxCategory category) async {
    await DatabaseHelper.instance.insertCategory(category);
    await load();
  }

  Future<void> update(TxCategory category) async {
    await DatabaseHelper.instance.updateCategory(category);
    await load();
  }

  Future<void> remove(String id) async {
    await DatabaseHelper.instance.deleteCategory(id);
    await load();
  }

  Future<bool> isInUse(String id) async =>
      await DatabaseHelper.instance.countTransactionsForCategory(id) > 0;
}

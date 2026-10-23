import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/account.dart';
import '../utils/calculations.dart';

class AccountsProvider extends ChangeNotifier {
  List<Account> accounts = [];
  Map<String, double> balances = {};

  Future<void> load() async {
    accounts = await DatabaseHelper.instance.getAccounts();
    final transactions = await DatabaseHelper.instance.getTransactions();
    balances = balancesByAccount(accounts, transactions);
    notifyListeners();
  }

  double balanceOf(String accountId) => balances[accountId] ?? 0;

  double get totalBalance =>
      balances.values.fold(0, (sum, balance) => sum + balance);

  Account? byId(String id) {
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  Future<void> add(Account account) async {
    await DatabaseHelper.instance.insertAccount(account);
    await load();
  }

  Future<void> update(Account account) async {
    await DatabaseHelper.instance.updateAccount(account);
    await load();
  }

  Future<void> remove(String id) async {
    await DatabaseHelper.instance.deleteAccount(id);
    await load();
  }

  Future<bool> isInUse(String id) async =>
      await DatabaseHelper.instance.countTransactionsForAccount(id) > 0;
}

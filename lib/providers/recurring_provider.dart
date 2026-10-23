import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/recurring.dart';
import '../utils/recurrence.dart';

class RecurringProvider extends ChangeNotifier {
  List<RecurringRule> rules = [];

  Future<void> load() async {
    rules = await DatabaseHelper.instance.getRecurringRules();
    notifyListeners();
  }

  // Reglas ordenadas por fecha de vencimiento (lo urgente primero).
  List<RecurringRule> get upcoming =>
      [...rules]..sort((a, b) => a.nextDue.compareTo(b.nextDue));

  Future<void> add(RecurringRule rule) async {
    await DatabaseHelper.instance.insertRecurringRule(rule);
    await load();
  }

  Future<void> update(RecurringRule rule) async {
    await DatabaseHelper.instance.updateRecurringRule(rule);
    await load();
  }

  Future<void> remove(String id) async {
    await DatabaseHelper.instance.deleteRecurringRule(id);
    await load();
  }

  // Tras registrar u omitir un pago, el siguiente vencimiento avanza.
  Future<void> advance(RecurringRule rule) async {
    await update(
        rule.copyWith(nextDue: advanceDueDate(rule.nextDue, rule.frequency)));
  }

  // Posponer mueve el vencimiento un día.
  Future<void> postpone(RecurringRule rule) async {
    await update(
        rule.copyWith(nextDue: rule.nextDue.add(const Duration(days: 1))));
  }
}

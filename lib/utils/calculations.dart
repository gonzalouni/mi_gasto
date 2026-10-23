import '../models/account.dart';
import '../models/budget.dart';
import '../models/transaction.dart';

class MonthSummary {
  const MonthSummary({required this.income, required this.expense});

  final double income;
  final double expense;

  double get balance => income - expense;
}

bool isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

List<AppTransaction> filterByMonth(Iterable<AppTransaction> transactions, DateTime month) =>
    transactions.where((t) => isSameMonth(t.date, month)).toList();

MonthSummary summarize(Iterable<AppTransaction> transactions) {
  double income = 0;
  double expense = 0;
  for (final t in transactions) {
    // Las transferencias entre cuentas no son ingreso ni gasto.
    if (t.type == 'income') {
      income += t.amount;
    } else if (t.type == 'expense') {
      expense += t.amount;
    }
  }
  return MonthSummary(income: income, expense: expense);
}

Map<String, double> totalsByCategory(
  Iterable<AppTransaction> transactions, {
  required String type,
}) {
  final totals = <String, double>{};
  for (final t in transactions) {
    if (t.type != type) continue;
    totals[t.categoryId] = (totals[t.categoryId] ?? 0) + t.amount;
  }
  return totals;
}

Map<int, double> totalsByDay(
  Iterable<AppTransaction> transactions, {
  required String type,
}) {
  final totals = <int, double>{};
  for (final t in transactions) {
    if (t.type != type) continue;
    totals[t.date.day] = (totals[t.date.day] ?? 0) + t.amount;
  }
  return totals;
}

double accountBalance(Account account, Iterable<AppTransaction> transactions) {
  double balance = account.initialBalance;
  for (final t in transactions) {
    if (t.isTransfer) {
      // Una transferencia resta en la cuenta origen y suma en la destino.
      if (t.accountId == account.id) balance -= t.amount;
      if (t.toAccountId == account.id) balance += t.amount;
      continue;
    }
    if (t.accountId != account.id) continue;
    balance += t.isIncome ? t.amount : -t.amount;
  }
  return balance;
}

Map<String, double> balancesByAccount(
  List<Account> accounts,
  Iterable<AppTransaction> transactions,
) =>
    {for (final account in accounts) account.id: accountBalance(account, transactions)};

// Presupuestos --------------------------------------------------------------
//
// El periodo presupuestal empieza el "día de pago" configurado, no el día 1:
// ej. con día de pago 15, el periodo va del 15 de octubre al 14 de noviembre.

int _clampDay(int year, int month, int payDay) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return payDay.clamp(1, lastDay);
}

DateTime budgetPeriodStart(DateTime now, int payDay) {
  final day = _clampDay(now.year, now.month, payDay);
  var start = DateTime(now.year, now.month, day);
  if (now.isBefore(start)) {
    start = DateTime(now.year, now.month - 1,
        _clampDay(now.year, now.month - 1, payDay));
  }
  return start;
}

DateTime budgetPeriodEnd(DateTime now, int payDay) {
  final start = budgetPeriodStart(now, payDay);
  return DateTime(start.year, start.month + 1,
      _clampDay(start.year, start.month + 1, payDay));
}

double spentInPeriod(
  Iterable<AppTransaction> transactions, {
  required DateTime start,
  required DateTime end,
  String? categoryId,
}) {
  double total = 0;
  for (final t in transactions) {
    // Solo los gastos consumen presupuesto (no ingresos ni transferencias).
    if (t.type != 'expense') continue;
    if (t.date.isBefore(start) || !t.date.isBefore(end)) continue;
    if (categoryId != null && t.categoryId != categoryId) continue;
    total += t.amount;
  }
  return total;
}

class BudgetStatus {
  const BudgetStatus({
    required this.spent,
    required this.amount,
    required this.elapsedDays,
    required this.totalDays,
  });

  final double spent;
  final double amount;
  final int elapsedDays;
  final int totalDays;

  double get ratio => amount <= 0 ? 0 : spent / amount;

  double get remaining => amount - spent;

  // Lo que "deberías" haber gastado hoy si repartes el presupuesto parejo.
  double get expectedByNow =>
      totalDays <= 0 ? 0 : amount * elapsedDays / totalDays;

  // A cuánto llegarías al final del periodo si sigues al ritmo actual.
  double get projectedTotal =>
      elapsedDays <= 0 ? spent : spent / elapsedDays * totalDays;

  bool get isOverBudget => amount > 0 && spent > amount;

  bool get isOverPace => amount > 0 && spent > expectedByNow;

  bool get reached80 => ratio >= 0.8;
}

BudgetStatus budgetStatus({
  required Iterable<AppTransaction> transactions,
  required String categoryId,
  required double amount,
  required DateTime start,
  required DateTime end,
  required DateTime now,
}) {
  final spent = spentInPeriod(
    transactions,
    start: start,
    end: end,
    // 'total' significa presupuesto global: suma todas las categorías.
    categoryId: categoryId == 'total' ? null : categoryId,
  );
  final totalDays = end.difference(start).inDays;
  final elapsedDays = (now.difference(start).inDays + 1).clamp(1, totalDays);
  return BudgetStatus(
    spent: spent,
    amount: amount,
    elapsedDays: elapsedDays,
    totalDays: totalDays,
  );
}

class BudgetAlert {
  const BudgetAlert({
    required this.budget,
    required this.exceeded,
    required this.ratio,
  });

  final Budget budget;
  final bool exceeded;
  final double ratio;
}

/// Detecta si el movimiento recién guardado hizo cruzar el 80% o el 100% de
/// algún presupuesto (el de su categoría o el total).
///
/// Compara el estado antes y después del movimiento, así solo avisa en el
/// momento en que se cruza el umbral y no en cada gasto posterior.
List<BudgetAlert> budgetCrossingAlerts({
  required Iterable<Budget> budgets,
  required Iterable<AppTransaction> before,
  required Iterable<AppTransaction> after,
  required String categoryId,
  required DateTime now,
  required int payDay,
}) {
  final start = budgetPeriodStart(now, payDay);
  final end = budgetPeriodEnd(now, payDay);
  final alerts = <BudgetAlert>[];
  for (final budget in budgets) {
    if (!budget.isTotal && budget.categoryId != categoryId) continue;
    final statusBefore = budgetStatus(
      transactions: before,
      categoryId: budget.categoryId,
      amount: budget.amount,
      start: start,
      end: end,
      now: now,
    );
    final statusAfter = budgetStatus(
      transactions: after,
      categoryId: budget.categoryId,
      amount: budget.amount,
      start: start,
      end: end,
      now: now,
    );
    final crossed100 = !statusBefore.isOverBudget && statusAfter.isOverBudget;
    final crossed80 = statusBefore.ratio < 0.8 && statusAfter.ratio >= 0.8;
    if (crossed100) {
      alerts.add(BudgetAlert(
          budget: budget, exceeded: true, ratio: statusAfter.ratio));
    } else if (crossed80) {
      alerts.add(BudgetAlert(
          budget: budget, exceeded: false, ratio: statusAfter.ratio));
    }
  }
  return alerts;
}

// Reportes -----------------------------------------------------------------

class MonthlyTotal {
  const MonthlyTotal({required this.month, required this.total});

  final DateTime month;
  final double total;
}

/// Totales por mes para los últimos [months] meses, terminando en [lastMonth]
/// (inclusive), en orden cronológico. Sirve para las gráficas de tendencia.
List<MonthlyTotal> monthlyTotals(
  Iterable<AppTransaction> transactions, {
  required String type,
  required DateTime lastMonth,
  required int months,
}) {
  final result = <MonthlyTotal>[];
  for (var i = months - 1; i >= 0; i--) {
    final month = DateTime(lastMonth.year, lastMonth.month - i);
    double total = 0;
    for (final t in transactions) {
      if (t.type != type) continue;
      if (isSameMonth(t.date, month)) total += t.amount;
    }
    result.add(MonthlyTotal(month: month, total: total));
  }
  return result;
}

/// Tasa de ahorro del periodo: (ingresos - gastos) / ingresos.
/// Devuelve 0 cuando no hay ingresos.
double savingsRate({required double income, required double expense}) =>
    income <= 0 ? 0 : (income - expense) / income;

/// Gasto promedio por día.
double dailyAverage({required double expense, required int days}) =>
    days <= 0 ? 0 : expense / days;

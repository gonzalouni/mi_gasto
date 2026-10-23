import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/recurring.dart';
import '../models/transaction.dart';
import '../providers/accounts_provider.dart';
import '../providers/budgets_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../services/budget_alerts.dart';
import '../utils/calculations.dart';
import '../utils/formatters.dart';
import '../widgets/app_icon.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const AppIcon('arrowLeft'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Movimientos recurrentes'),
      ),
      body: Consumer2<RecurringProvider, SettingsProvider>(
        builder: (context, recurring, settings, _) {
          final rules = recurring.upcoming;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (rules.isEmpty)
                const _EmptyPayments()
              else
                for (final rule in rules)
                  _RuleTile(
                    rule: rule,
                    currency: settings.currency,
                    onRegister: () => _register(context, rule),
                    onSkip: () => _skip(context, rule),
                    onPostpone: () => _postpone(context, rule),
                    onEdit: () => _showRuleDialog(context, rule: rule),
                  ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRuleDialog(context),
        child: const AppIcon('add'),
      ),
    );
  }

  Future<void> _register(BuildContext context, RecurringRule rule) async {
    final messenger = ScaffoldMessenger.of(context);
    final transactions = context.read<TransactionsProvider>();
    final accounts = context.read<AccountsProvider>();
    final recurring = context.read<RecurringProvider>();
    final budgets = context.read<BudgetsProvider>();
    final categories = context.read<CategoriesProvider>();
    final settings = context.read<SettingsProvider>();
    final before = transactions.all;
    // El movimiento se registra con la fecha de hoy: es el momento en que el
    // usuario confirma el pago, así afecta al mes actual de inmediato.
    await transactions.add(AppTransaction(
      id: const Uuid().v4(),
      type: rule.type,
      amount: rule.amount,
      accountId: rule.accountId,
      categoryId: rule.categoryId,
      date: DateTime.now(),
      note: rule.note,
      createdAt: DateTime.now(),
    ));
    await accounts.load();
    await recurring.advance(rule);
    messenger.showSnackBar(
        const SnackBar(content: Text('Movimiento registrado')));

    // Aviso si este gasto fue el que cruzó el 80% o el 100% del presupuesto.
    if (rule.type == 'expense') {
      final alerts = budgetCrossingAlerts(
        budgets: budgets.budgets,
        before: before,
        after: transactions.all,
        categoryId: rule.categoryId,
        now: DateTime.now(),
        payDay: settings.payDay,
      );
      if (alerts.isNotEmpty && context.mounted) {
        await showBudgetAlerts(
          context,
          alerts: alerts,
          categoryName: (id) => categories.byId(id)?.name ?? '',
        );
      }
    }
  }

  Future<void> _skip(BuildContext context, RecurringRule rule) async {
    final messenger = ScaffoldMessenger.of(context);
    await context.read<RecurringProvider>().advance(rule);
    messenger
        .showSnackBar(const SnackBar(content: Text('Movimiento omitido')));
  }

  Future<void> _postpone(BuildContext context, RecurringRule rule) async {
    final messenger = ScaffoldMessenger.of(context);
    await context.read<RecurringProvider>().postpone(rule);
    messenger
        .showSnackBar(const SnackBar(content: Text('Vencimiento pospuesto')));
  }

  Future<void> _showRuleDialog(BuildContext context,
      {RecurringRule? rule}) async {
    final recurring = context.read<RecurringProvider>();
    final categoriesProvider = context.read<CategoriesProvider>();
    final accountsProvider = context.read<AccountsProvider>();

    final amountController = TextEditingController(
      text: rule == null
          ? ''
          : (rule.amount == rule.amount.roundToDouble()
              ? rule.amount.toInt().toString()
              : rule.amount.toString()),
    );
    final noteController = TextEditingController(text: rule?.note ?? '');
    String type = rule?.type ?? 'expense';
    String? categoryId = rule?.categoryId;
    String? accountId = rule?.accountId ??
        (accountsProvider.accounts.isEmpty
            ? null
            : accountsProvider.accounts.first.id);
    String frequency = rule?.frequency ?? 'monthly';
    DateTime nextDue = rule?.nextDue ?? DateTime.now();
    String? errorText;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(rule == null
              ? 'Nuevo movimiento recurrente'
              : 'Editar movimiento recurrente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: 'expense',
                        label: Text('Gasto'),
                        icon: AppIcon('arrowDown')),
                    ButtonSegment(
                        value: 'income',
                        label: Text('Ingreso'),
                        icon: AppIcon('arrowUp')),
                  ],
                  selected: {type},
                  onSelectionChanged: (selection) => setState(() {
                    type = selection.first;
                    categoryId = null;
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Monto',
                    border: const OutlineInputBorder(),
                    errorText: errorText,
                  ),
                  onChanged: (_) => setState(() => errorText = null),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final category in categoriesProvider.byType(type))
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => categoryId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: accountId,
                  decoration: const InputDecoration(
                    labelText: 'Cuenta',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final account in accountsProvider.accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => accountId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  decoration: const InputDecoration(
                    labelText: 'Frecuencia',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final entry in kFrequencyLabels.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => frequency = value ?? 'monthly'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const AppIcon('calendar'),
                  title: Text(
                      'Próximo: ${capitalize(formatDate(nextDue, "d 'de' MMMM"))}'),
                  trailing: const AppIcon('caretRight', size: 20),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: nextDue,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => nextDue = picked);
                  },
                ),
                TextField(
                  controller: noteController,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Nota (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (rule != null)
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop({'delete': true}),
                child: Text('Eliminar',
                    style: TextStyle(color: Colors.red.shade700)),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(
                    amountController.text.trim().replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  setState(() => errorText = 'Ingresa un monto válido');
                  return;
                }
                if (categoryId == null || accountId == null) {
                  setState(() => errorText = 'Elige categoría y cuenta');
                  return;
                }
                Navigator.of(dialogContext).pop({
                  'type': type,
                  'amount': amount,
                  'categoryId': categoryId,
                  'accountId': accountId,
                  'frequency': frequency,
                  'nextDue': nextDue,
                  'note': noteController.text.trim(),
                });
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !context.mounted) return;

    if (result['delete'] == true) {
      await recurring.remove(rule!.id);
      return;
    }

    final newRule = RecurringRule(
      id: rule?.id ?? const Uuid().v4(),
      type: result['type'] as String,
      amount: result['amount'] as double,
      accountId: result['accountId'] as String,
      categoryId: result['categoryId'] as String,
      note: result['note'] as String,
      frequency: result['frequency'] as String,
      nextDue: result['nextDue'] as DateTime,
    );
    if (rule == null) {
      await recurring.add(newRule);
    } else {
      await recurring.update(newRule);
    }
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.currency,
    required this.onRegister,
    required this.onSkip,
    required this.onPostpone,
    required this.onEdit,
  });

  final RecurringRule rule;
  final String currency;
  final VoidCallback? onRegister;
  final VoidCallback onSkip;
  final VoidCallback onPostpone;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final category = context.watch<CategoriesProvider>().byId(rule.categoryId);
    // Solo se marca vencido si la fecha pasó de día; un pago de hoy no lo está.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdue = rule.nextDue.isBefore(today);
    // Un solo registro por ciclo: "Registrar" se activa cuando el pago vence.
    final isDue = !rule.nextDue.isAfter(today);
    final sign = rule.type == 'income' ? '+' : '-';
    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(category?.color ?? 0xFF90A4AE)
                        .withValues(alpha: 0.2),
                    child: AppIcon(category?.icon ?? 'label',
                        size: 20, color: Color(category?.color ?? 0xFF90A4AE)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category?.name ?? 'Sin categoría'),
                        Text(
                          '${overdue ? '¡Vencido! ' : ''}Vence ${formatDate(rule.nextDue, 'd MMM')} · ${kFrequencyLabels[rule.frequency] ?? rule.frequency}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: overdue ? Colors.red.shade400 : null,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$sign ${formatMoney(rule.amount, currency)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: isDue ? onRegister : null,
                    icon: const AppIcon('check', size: 16),
                    label: const Text('Registrar'),
                  ),
                  TextButton.icon(
                    onPressed: onSkip,
                    icon: const AppIcon('closeCircle', size: 16),
                    label: const Text('Omitir'),
                  ),
                  TextButton.icon(
                    onPressed: onPostpone,
                    icon: const AppIcon('calendarAdd', size: 16),
                    label: const Text('Posponer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPayments extends StatelessWidget {
  const _EmptyPayments();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          AppIcon('moneyTime',
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('Sin movimientos programados',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
              'Toca el botón + para programar alquiler, sueldo o suscripciones.'),
        ],
      ),
    );
  }
}

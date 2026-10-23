import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/budget.dart';
import '../providers/budgets_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../utils/calculations.dart';
import '../utils/formatters.dart';
import '../widgets/app_icon.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer4<TransactionsProvider, BudgetsProvider,
        CategoriesProvider, SettingsProvider>(
      builder: (context, transactions, budgetList, categories, settings, _) {
        final now = DateTime.now();
        final start = budgetPeriodStart(now, settings.payDay);
        final end = budgetPeriodEnd(now, settings.payDay);
        final rangeLabel =
            '${formatDate(start, 'd MMM')} – ${formatDate(end, 'd MMM')}';

        final budgets = [...budgetList.budgets]
          ..sort((a, b) {
            if (a.isTotal) return -1;
            if (b.isTotal) return 1;
            return a.categoryId.compareTo(b.categoryId);
          });

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Card(
              child: ListTile(
                leading: const AppIcon('calendar'),
                title: Text('Periodo: $rangeLabel'),
                subtitle: Text('Día de pago: ${settings.payDay}'),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Presupuestos',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const AppIcon('addCircle'),
                  onPressed: () => _showBudgetDialog(context),
                ),
              ],
            ),
            if (budgets.isEmpty)
              const _EmptyBudgets()
            else
              for (final budget in budgets)
                _BudgetCard(
                  budget: budget,
                  status: budgetStatus(
                    transactions: transactions.all,
                    categoryId: budget.categoryId,
                    amount: budget.amount,
                    start: start,
                    end: end,
                    now: now,
                  ),
                  name: budget.isTotal
                      ? 'Presupuesto total'
                      : categories.byId(budget.categoryId)?.name ??
                          'Sin categoría',
                  icon: budget.isTotal
                      ? 'moneyBag'
                      : categories.byId(budget.categoryId)?.icon ?? 'label',
                  color: budget.isTotal
                      ? Theme.of(context).colorScheme.primary
                      : Color(categories.byId(budget.categoryId)?.color ??
                          0xFF90A4AE),
                  currency: settings.currency,
                  onEdit: () => _showBudgetDialog(context, budget: budget),
                ),
          ],
        );
      },
    );
  }

  Future<void> _showBudgetDialog(BuildContext context, {Budget? budget}) async {
    final budgetsProvider = context.read<BudgetsProvider>();
    final categoriesProvider = context.read<CategoriesProvider>();
    final amountController = TextEditingController(
      text: budget == null
          ? ''
          : (budget.amount == budget.amount.roundToDouble()
              ? budget.amount.toInt().toString()
              : budget.amount.toString()),
    );
    String categoryId = budget?.categoryId ?? kTotalBudgetCategoryId;
    String? errorText;

    final options = categoriesProvider.byType('expense');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(budget == null ? 'Nuevo presupuesto' : 'Editar presupuesto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: kTotalBudgetCategoryId,
                    child: Text('Presupuesto total'),
                  ),
                  for (final category in options)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => categoryId = value ?? kTotalBudgetCategoryId),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Monto del periodo',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
                onChanged: (_) => setState(() => errorText = null),
              ),
            ],
          ),
          actions: [
            if (budget != null)
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
                Navigator.of(dialogContext).pop({
                  'categoryId': categoryId,
                  'amount': amount,
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
      await budgetsProvider.remove(budget!.id);
      return;
    }

    final amount = result['amount'] as double;
    final selected = result['categoryId'] as String;

    // Si la categoría ya tenía presupuesto se actualiza en vez de duplicarlo.
    final existing = budgetsProvider.byCategoryId(selected);
    if (budget != null && (existing == null || existing.id == budget.id)) {
      await budgetsProvider.update(Budget(
        id: budget.id,
        categoryId: selected,
        amount: amount,
      ));
    } else if (existing != null) {
      if (budget != null) await budgetsProvider.remove(budget.id);
      await budgetsProvider.update(Budget(
        id: existing.id,
        categoryId: selected,
        amount: amount,
      ));
    } else {
      await budgetsProvider.add(Budget(
        id: const Uuid().v4(),
        categoryId: selected,
        amount: amount,
      ));
    }
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.status,
    required this.name,
    required this.icon,
    required this.color,
    required this.currency,
    required this.onEdit,
  });

  final Budget budget;
  final BudgetStatus status;
  final String name;
  final String icon;
  final Color color;
  final String currency;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final barColor = status.isOverBudget
        ? Colors.red.shade700
        : status.reached80
            ? Colors.orange.shade700
            : Colors.green.shade700;
    final paceFraction =
        status.totalDays <= 0 ? 0.0 : status.elapsedDays / status.totalDays;

    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.2),
                    child: AppIcon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(name)),
                  Text(
                    '${formatMoney(status.spent, currency)} de ${formatMoney(status.amount, currency)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 12,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: status.ratio.clamp(0.0, 1.0),
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(barColor),
                        ),
                      ),
                    ),
                    // Marcador de ritmo: lo que "deberías" haber gastado hoy.
                    Align(
                      alignment: Alignment(-1 + 2 * paceFraction, 0),
                      child: Container(
                        width: 2,
                        height: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      status.isOverBudget
                          ? 'Te has pasado ${formatMoney(-status.remaining, currency)}'
                          : 'Te quedan ${formatMoney(status.remaining, currency)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    'Al ritmo actual: ${formatMoney(status.projectedTotal, currency)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (status.isOverBudget || status.reached80 || status.isOverPace)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (status.isOverBudget)
                        _statusChip('Superado', Colors.red.shade700)
                      else if (status.reached80)
                        _statusChip('80% usado', Colors.orange.shade700),
                      if (status.isOverPace && !status.isOverBudget)
                        _statusChip('Sobre el ritmo', Colors.orange.shade700),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      );
}

class _EmptyBudgets extends StatelessWidget {
  const _EmptyBudgets();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          AppIcon('checklist',
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('Aún no hay presupuestos',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Toca el botón + para crear el primero.'),
        ],
      ),
    );
  }
}

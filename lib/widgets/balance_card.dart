import 'package:flutter/material.dart';

import '../utils/calculations.dart';
import '../utils/formatters.dart';
import 'app_icon.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.summary, required this.currency});

  final MonthSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Balance del mes',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              formatMoney(summary.balance, currency),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    label: 'Ingresos',
                    amount: formatMoney(summary.income, currency),
                    icon: 'arrowUp',
                    color: Colors.green.shade700,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: 'Gastos',
                    amount: formatMoney(summary.expense, currency),
                    icon: 'arrowDown',
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final String amount;
  final String icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIcon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(amount,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../models/budget.dart';
import '../utils/calculations.dart';
import '../widgets/app_icon.dart';

/// Muestra el aviso cuando un movimiento recién guardado cruzó el 80% o el
/// 100% de un presupuesto.
Future<void> showBudgetAlerts(
  BuildContext context, {
  required List<BudgetAlert> alerts,
  required String Function(String categoryId) categoryName,
}) async {
  if (alerts.isEmpty) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Aviso de presupuesto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final alert in alerts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(
                    alert.exceeded ? 'warning' : 'infoCircle',
                    size: 20,
                    color: alert.exceeded
                        ? Colors.red.shade400
                        : Colors.orange.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert.exceeded
                          ? 'Superaste el ${_label(alert.budget, categoryName)}.'
                          : 'El ${_label(alert.budget, categoryName)} llegó al '
                              '${(alert.ratio * 100).round()}%.',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}

String _label(Budget budget, String Function(String) categoryName) =>
    budget.isTotal
        ? 'presupuesto total'
        : 'presupuesto de ${categoryName(budget.categoryId)}';

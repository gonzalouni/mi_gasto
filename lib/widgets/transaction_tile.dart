import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../utils/formatters.dart';
import 'app_icon.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.accountName,
    required this.currency,
    this.onTap,
  });

  final AppTransaction transaction;
  final String categoryName;
  final String categoryIcon;
  final int categoryColor;
  final String accountName;
  final String currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    final isTransfer = transaction.isTransfer;
    final amountColor = isTransfer
        ? Theme.of(context).colorScheme.onSurface
        : (isIncome ? Colors.green.shade700 : Colors.red.shade700);
    final amountText = isTransfer
        ? formatMoney(transaction.amount, currency)
        : '${isIncome ? '+' : '-'} ${formatMoney(transaction.amount, currency)}';
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Color(categoryColor).withValues(alpha: 0.2),
        child: AppIcon(categoryIcon, size: 20, color: Color(categoryColor)),
      ),
      title: Text(categoryName),
      subtitle: Text(
        transaction.note.isEmpty
            ? accountName
            : '$accountName · ${transaction.note}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        amountText,
        style: TextStyle(fontWeight: FontWeight.bold, color: amountColor),
      ),
    );
  }
}

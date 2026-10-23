import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/transaction.dart';
import '../providers/accounts_provider.dart';
import '../providers/budgets_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../services/budget_alerts.dart';
import '../utils/calculations.dart';
import '../utils/formatters.dart';
import '../widgets/app_icon.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key, this.existing});

  final AppTransaction? existing;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _type = 'expense';
  String? _categoryId;
  String? _accountId;
  String? _toAccountId;
  late DateTime _date;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _type = existing.type;
      _amountController.text = existing.amount == existing.amount.roundToDouble()
          ? existing.amount.toInt().toString()
          : existing.amount.toString();
      _noteController.text = existing.note;
      _categoryId = existing.categoryId;
      _accountId = existing.accountId;
      _toAccountId = existing.toAccountId;
      _date = existing.date;
    } else {
      _date = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final symbol = kCurrencySymbols[settings.currency] ?? settings.currency;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const AppIcon('arrowLeft'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEditing ? 'Editar movimiento' : 'Nuevo movimiento'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const AppIcon('trash'),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 'expense',
                label: Text('Gasto'),
                icon: AppIcon('arrowDown'),
              ),
              ButtonSegment(
                value: 'income',
                label: Text('Ingreso'),
                icon: AppIcon('arrowUp'),
              ),
              ButtonSegment(
                value: 'transfer',
                label: Text('Transf.'),
                icon: AppIcon('arrowSwapHorizontal'),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (selection) => setState(() {
              _type = selection.first;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
            ],
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Monto',
              prefixText: '$symbol ',
            ),
          ),
          const SizedBox(height: 16),
          if (_type != 'transfer') ...[
            Text('Categoría', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Consumer<CategoriesProvider>(
              builder: (context, categories, _) {
                final options = categories.byType(_type);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in options)
                      ChoiceChip(
                        showCheckmark: false,
                        avatar: AppIcon(
                          category.icon,
                          size: 18,
                          color: Color(category.color),
                        ),
                        label: Text(category.name),
                        selected: _categoryId == category.id,
                        onSelected: (_) =>
                            setState(() => _categoryId = category.id),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          Consumer<AccountsProvider>(
            builder: (context, accounts, _) {
              return Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _accountId,
                    decoration: InputDecoration(
                      labelText:
                          _type == 'transfer' ? 'Cuenta origen' : 'Cuenta',
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final account in accounts.accounts)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(account.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _accountId = value),
                  ),
                  if (_type == 'transfer') ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _toAccountId,
                      decoration: const InputDecoration(
                        labelText: 'Cuenta destino',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final account in accounts.accounts)
                          DropdownMenuItem(
                            value: account.id,
                            child: Text(account.name),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _toAccountId = value),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const AppIcon('calendar'),
            title: Text(capitalize(formatDate(_date, "d 'de' MMMM 'de' y"))),
            trailing: const AppIcon('caretRight', size: 20),
            onTap: _pickDate,
          ),
          TextField(
            controller: _noteController,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Nota (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _date =
          DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute);
    });
  }

  Future<void> _save() async {
    final amount =
        double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      _showMessage('Ingresa un monto válido');
      return;
    }
    if (_type != 'transfer' && _categoryId == null) {
      _showMessage('Elige una categoría');
      return;
    }
    if (_accountId == null) {
      _showMessage('Elige una cuenta');
      return;
    }
    if (_type == 'transfer') {
      if (_toAccountId == null) {
        _showMessage('Elige la cuenta destino');
        return;
      }
      if (_toAccountId == _accountId) {
        _showMessage('Las cuentas deben ser distintas');
        return;
      }
    }

    final transactions = context.read<TransactionsProvider>();
    final accounts = context.read<AccountsProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final currency = settingsProvider.currency;
    final budgets = context.read<BudgetsProvider>();
    final categories = context.read<CategoriesProvider>();
    final before = transactions.all;
    final existing = widget.existing;

    // Un movimiento puede dejar la cuenta en negativo (ej. gastaste antes de
    // registrar tu ingreso), pero solo con confirmación explícita.
    if (_type != 'income') {
      double projected = accounts.balanceOf(_accountId!);
      if (existing != null && existing.accountId == _accountId) {
        projected += existing.isIncome ? -existing.amount : existing.amount;
      }
      projected -= amount;
      if (projected < 0) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Saldo en negativo'),
            content: Text('Con este movimiento la cuenta quedará en '
                '${formatMoney(projected, currency)}. ¿Continuar?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Continuar'),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
      }
    }

    final transaction = AppTransaction(
      id: existing?.id ?? const Uuid().v4(),
      type: _type,
      amount: amount,
      accountId: _accountId!,
      categoryId: _type == 'transfer' ? 'cat_transferencia' : _categoryId!,
      date: _date,
      note: _noteController.text.trim(),
      createdAt: existing?.createdAt ?? DateTime.now(),
      toAccountId: _type == 'transfer' ? _toAccountId : null,
    );
    if (existing == null) {
      await transactions.add(transaction);
    } else {
      await transactions.update(transaction);
    }
    await accounts.load();

    // Aviso si este gasto fue el que cruzó el 80% o el 100% del presupuesto.
    if (_type == 'expense') {
      final alerts = budgetCrossingAlerts(
        budgets: budgets.budgets,
        before: before,
        after: transactions.all,
        categoryId: _categoryId!,
        now: DateTime.now(),
        payDay: settingsProvider.payDay,
      );
      if (alerts.isNotEmpty && mounted) {
        await showBudgetAlerts(
          context,
          alerts: alerts,
          categoryName: (id) => categories.byId(id)?.name ?? '',
        );
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final transactions = context.read<TransactionsProvider>();
    final accounts = context.read<AccountsProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: const Text('¿Seguro que quieres eliminar este movimiento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await transactions.remove(widget.existing!.id);
    await accounts.load();
    if (mounted) Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../providers/accounts_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/category_icons.dart';
import '../utils/formatters.dart';
import '../widgets/app_icon.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AccountsProvider, SettingsProvider>(
      builder: (context, accounts, settings, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Card(
              child: ListTile(
                title: const Text('Patrimonio total'),
                trailing: Text(
                  formatMoney(accounts.totalBalance, settings.currency),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cuentas',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const AppIcon('addCircle'),
                  onPressed: () => _showAccountDialog(context),
                ),
              ],
            ),
            if (accounts.accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Aún no tienes cuentas')),
              )
            else
              for (final account in accounts.accounts)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: AppIcon(
                        accountIconName(account.type),
                        size: 22,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(account.name),
                    subtitle:
                        Text(kAccountTypeLabels[account.type] ?? account.type),
                    trailing: Text(
                      formatMoney(
                          accounts.balanceOf(account.id), settings.currency),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () => _showAccountDialog(context, account: account),
                  ),
                ),
          ],
        );
      },
    );
  }

  Future<void> _showAccountDialog(BuildContext context, {Account? account}) async {
    final nameController = TextEditingController(text: account?.name);
    final balanceController = TextEditingController(
      text: account == null
          ? '0'
          : (account.initialBalance == account.initialBalance.roundToDouble()
              ? account.initialBalance.toInt().toString()
              : account.initialBalance.toString()),
    );
    String type = account?.type ?? 'cash';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(account == null ? 'Nueva cuenta' : 'Editar cuenta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final entry in kAccountTypeLabels.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (value) => setState(() => type = value ?? 'cash'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balanceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Saldo inicial'),
              ),
            ],
          ),
          actions: [
            if (account != null)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop({'delete': true}),
                child: Text('Eliminar',
                    style: TextStyle(color: Colors.red.shade700)),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop({
                'name': nameController.text.trim(),
                'type': type,
                'initialBalance': balanceController.text.trim(),
              }),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !context.mounted) return;

    if (result['delete'] == true) {
      final inUse = await context.read<AccountsProvider>().isInUse(account!.id);
      if (!context.mounted) return;
      if (inUse) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se puede eliminar: tiene movimientos')));
        return;
      }
      await context.read<AccountsProvider>().remove(account.id);
      return;
    }

    final name = result['name'] as String;
    final initialBalance = double.tryParse(
            (result['initialBalance'] as String).replaceAll(',', '.')) ??
        0;
    if (name.isEmpty || !context.mounted) return;

    final provider = context.read<AccountsProvider>();
    final currency = context.read<SettingsProvider>().currency;
    if (account == null) {
      await provider.add(Account(
        id: const Uuid().v4(),
        name: name,
        type: result['type'] as String,
        initialBalance: initialBalance,
        currency: currency,
      ));
    } else {
      await provider.update(Account(
        id: account.id,
        name: name,
        type: result['type'] as String,
        initialBalance: initialBalance,
        currency: account.currency,
      ));
    }
  }
}

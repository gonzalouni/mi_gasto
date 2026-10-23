import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../providers/accounts_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../utils/formatters.dart';
import '../widgets/app_icon.dart';
import '../widgets/balance_card.dart';
import '../widgets/transaction_tile.dart';
import 'accounts_screen.dart';
import 'add_transaction_screen.dart';
import 'budgets_screen.dart';
import 'payments_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _titles = ['MiGasto', 'Reportes', 'Presupuestos', 'Cuentas', 'Ajustes'];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _SummaryTab(),
      const ReportsScreen(),
      const BudgetsScreen(),
      const AccountsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: pages[_index],
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const AddTransactionScreen()),
              ),
              icon: const AppIcon('add'),
              label: const Text('Añadir'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: AppIcon('home'),
            label: 'Resumen',
          ),
          NavigationDestination(
            icon: AppIcon('chartPie'),
            label: 'Reportes',
          ),
          NavigationDestination(
            icon: AppIcon('checklist'),
            label: 'Presup.',
          ),
          NavigationDestination(
            icon: AppIcon('wallet'),
            label: 'Cuentas',
          ),
          NavigationDestination(
            icon: AppIcon('settings'),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

class _SummaryTab extends StatefulWidget {
  const _SummaryTab();

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> {
  String _query = '';
  String _typeFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Consumer3<TransactionsProvider, SettingsProvider,
        CategoriesProvider>(
      builder: (context, transactions, settings, categories, _) {
        final query = _query.trim().toLowerCase();
        final visible = transactions.monthTransactions.where((t) {
          if (_typeFilter != 'all' && t.type != _typeFilter) return false;
          if (query.isEmpty) return true;
          final categoryName =
              categories.byId(t.categoryId)?.name.toLowerCase() ?? '';
          return t.note.toLowerCase().contains(query) ||
              categoryName.contains(query);
        }).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _MonthSelector(
              month: transactions.selectedMonth,
              onChanged: transactions.selectMonth,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: AppIcon('search', size: 18),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 34,
                  minHeight: 34,
                ),
                hintText: 'Buscar por nota o categoría',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _filterChip('Todos', 'all'),
                _filterChip('Gastos', 'expense'),
                _filterChip('Ingresos', 'income'),
                _filterChip('Transf.', 'transfer'),
              ],
            ),
            const SizedBox(height: 8),
            BalanceCard(
              summary: transactions.summary,
              currency: settings.currency,
            ),
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaymentsScreen()),
                ),
                leading: const AppIcon('moneyTime'),
                title: const Text('Movimientos recurrentes'),
                subtitle: const Text('Gastos e ingresos programados'),
                trailing: const AppIcon('caretRight', size: 20),
              ),
            ),
            const SizedBox(height: 16),
            if (visible.isEmpty)
              const _EmptyState()
            else
              ..._groupedByDay(visible).entries.map(
                    (entry) => _DaySection(
                      day: entry.key,
                      transactions: entry.value,
                      currency: settings.currency,
                    ),
                  ),
          ],
        );
      },
    );
  }

  Widget _filterChip(String label, String value) => FilterChip(
        label: Text(label),
        selected: _typeFilter == value,
        onSelected: (_) => setState(() => _typeFilter = value),
      );

  Map<DateTime, List<AppTransaction>> _groupedByDay(
      List<AppTransaction> transactions) {
    final groups = <DateTime, List<AppTransaction>>{};
    for (final transaction in transactions) {
      final day = DateTime(transaction.date.year, transaction.date.month,
          transaction.date.day);
      groups.putIfAbsent(day, () => []).add(transaction);
    }
    final sorted = groups.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return {for (final entry in sorted) entry.key: entry.value};
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = capitalize(formatDate(month, "MMMM 'de' y"));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const AppIcon('caretLeft'),
          onPressed: () =>
              onChanged(DateTime(month.year, month.month - 1)),
        ),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          icon: const AppIcon('caretRight'),
          onPressed: () =>
              onChanged(DateTime(month.year, month.month + 1)),
        ),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.transactions,
    required this.currency,
  });

  final DateTime day;
  final List<AppTransaction> transactions;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final categories = context.read<CategoriesProvider>();
    final accounts = context.read<AccountsProvider>();
    // Una transferencia entre cuentas no altera el total del día.
    final dayTotal = transactions.fold<double>(0, (sum, t) {
      if (t.isTransfer) return sum;
      return sum + (t.isIncome ? t.amount : -t.amount);
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              capitalize(formatDate(day, 'EEEE d MMM')),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              formatMoney(dayTotal, currency),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final transaction in transactions)
                TransactionTile(
                  transaction: transaction,
                  categoryName:
                      categories.byId(transaction.categoryId)?.name ??
                          'Sin categoría',
                  categoryIcon:
                      categories.byId(transaction.categoryId)?.icon ??
                          'label',
                  categoryColor:
                      categories.byId(transaction.categoryId)?.color ??
                          0xFF90A4AE,
                  accountName: transaction.isTransfer
                      ? '${accounts.byId(transaction.accountId)?.name ?? 'Cuenta'} → ${accounts.byId(transaction.toAccountId ?? '')?.name ?? 'Cuenta'}'
                      : accounts.byId(transaction.accountId)?.name ?? 'Cuenta',
                  currency: currency,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AddTransactionScreen(existing: transaction),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          AppIcon('receiptText',
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('Aún no hay movimientos este mes',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Toca "Añadir" para registrar tu primer gasto o ingreso.'),
        ],
      ),
    );
  }
}

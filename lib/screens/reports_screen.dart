import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/accounts_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../services/report_export.dart';
import '../utils/calculations.dart';
import '../utils/formatters.dart';
import '../widgets/app_icon.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  static const _trendMonths = 6;

  @override
  Widget build(BuildContext context) {
    return Consumer3<TransactionsProvider, CategoriesProvider,
        SettingsProvider>(
      builder: (context, transactions, categories, settings, _) {
        final month = transactions.selectedMonth;
        final now = DateTime.now();
        final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
        final elapsedDays = isSameMonth(month, now) ? now.day : daysInMonth;
        final summary = transactions.summary;
        final rate =
            savingsRate(income: summary.income, expense: summary.expense);
        final average =
            dailyAverage(expense: summary.expense, days: elapsedDays);

        final expenseByCategory = transactions.expenseByCategory;
        final incomeByCategory =
            totalsByCategory(transactions.monthTransactions, type: 'income');
        final expenseTotal =
            expenseByCategory.values.fold<double>(0, (sum, v) => sum + v);
        final incomeTotal =
            incomeByCategory.values.fold<double>(0, (sum, v) => sum + v);

        final expenseTrend = monthlyTotals(transactions.all,
            type: 'expense', lastMonth: month, months: _trendMonths);
        final incomeTrend = monthlyTotals(transactions.all,
            type: 'income', lastMonth: month, months: _trendMonths);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const AppIcon('caretLeft'),
                  onPressed: () => transactions
                      .selectMonth(DateTime(month.year, month.month - 1)),
                ),
                Text(capitalize(formatDate(month, "MMMM 'de' y")),
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const AppIcon('caretRight'),
                  onPressed: () => transactions
                      .selectMonth(DateTime(month.year, month.month + 1)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: 'trendUp',
                    label: 'Tasa de ahorro',
                    value: '${(rate * 100).round()}%',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    icon: 'moneyTime',
                    label: 'Promedio diario',
                    value: formatMoney(average, settings.currency),
                    sublabel: 'gasto por día',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _sectionTitle(context, 'Gastos por categoría'),
            if (expenseTotal == 0)
              const _NoData()
            else ...[
              const SizedBox(height: 200, child: _CategoryPieChart()),
              const SizedBox(height: 8),
              for (final entry in _sortedEntries(expenseByCategory))
                _LegendRow(
                  categoryName:
                      categories.byId(entry.key)?.name ?? 'Sin categoría',
                  color:
                      Color(categories.byId(entry.key)?.color ?? 0xFF90A4AE),
                  amount: formatMoney(entry.value, settings.currency),
                  percent: entry.value / expenseTotal * 100,
                ),
            ],
            const SizedBox(height: 24),
            _sectionTitle(context, 'Gastos por día'),
            if (expenseTotal == 0)
              const _NoData()
            else
              const SizedBox(height: 200, child: _DailyBarChart()),
            const SizedBox(height: 24),
            _sectionTitle(context, 'Calendario de gastos'),
            if (expenseTotal == 0)
              const _NoData()
            else
              _ExpenseCalendar(month: month, byDay: transactions.expenseByDay),
            const SizedBox(height: 24),
            _sectionTitle(
                context, 'Tendencia de gastos (últimos $_trendMonths meses)'),
            _TrendChart(data: expenseTrend, color: Colors.red.shade700),
            const SizedBox(height: 24),
            _sectionTitle(
                context, 'Tendencia de ingresos (últimos $_trendMonths meses)'),
            _TrendChart(data: incomeTrend, color: Colors.green.shade700),
            const SizedBox(height: 24),
            _sectionTitle(context, 'Flujo de dinero'),
            _CashFlowChart(income: incomeTrend, expense: expenseTrend),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FlowLegend(color: Colors.green, label: 'Ingresos'),
                SizedBox(width: 16),
                _FlowLegend(color: Colors.red, label: 'Gastos'),
              ],
            ),
            const SizedBox(height: 24),
            _sectionTitle(context, 'Resumen de ingresos'),
            if (incomeTotal == 0)
              const _NoData()
            else ...[
              const SizedBox(height: 200, child: _IncomePieChart()),
              const SizedBox(height: 8),
              for (final entry in _sortedEntries(incomeByCategory))
                _LegendRow(
                  categoryName:
                      categories.byId(entry.key)?.name ?? 'Sin categoría',
                  color:
                      Color(categories.byId(entry.key)?.color ?? 0xFF90A4AE),
                  amount: formatMoney(entry.value, settings.currency),
                  percent: entry.value / incomeTotal * 100,
                ),
              const SizedBox(height: 8),
              Text(
                'Total del mes: ${formatMoney(incomeTotal, settings.currency)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
            const SizedBox(height: 24),
            _sectionTitle(context, 'Resumen anual (${month.year})'),
            _YearSummary(year: month.year),
            const SizedBox(height: 24),
            _sectionTitle(context, 'Exportar reporte del mes'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exportReport(context, asPdf: true),
                    icon: const AppIcon('filePdf', size: 18),
                    label: const Text('PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exportReport(context, asPdf: false),
                    icon: const AppIcon('fileText', size: 18),
                    label: const Text('Excel'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );

  Future<void> _exportReport(BuildContext context,
      {required bool asPdf}) async {
    final messenger = ScaffoldMessenger.of(context);
    final transactionsProvider = context.read<TransactionsProvider>();
    final categories = context.read<CategoriesProvider>();
    final accounts = context.read<AccountsProvider>();
    final settings = context.read<SettingsProvider>();
    try {
      final month = transactionsProvider.selectedMonth;
      final monthTransactions = transactionsProvider.monthTransactions;
      final categoryNames = {
        for (final category in categories.categories) category.id: category.name,
      };
      final accountNames = {
        for (final account in accounts.accounts) account.id: account.name,
      };
      final file = asPdf
          ? await ReportExport.buildPdf(
              month: month,
              transactions: monthTransactions,
              categoryNames: categoryNames,
              accountNames: accountNames,
              currency: settings.currency,
            )
          : await ReportExport.buildExcel(
              month: month,
              transactions: monthTransactions,
              categoryNames: categoryNames,
              accountNames: accountNames,
              currency: settings.currency,
            );
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'Reporte MiGasto'),
      );
    } catch (error) {
      messenger.showSnackBar(
          SnackBar(content: Text('No se pudo exportar: $error')));
    }
  }

  List<MapEntry<String, double>> _sortedEntries(Map<String, double> map) {
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.sublabel,
  });

  final String icon;
  final String label;
  final String value;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(icon, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            if (sublabel != null)
              Text(sublabel!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text('Sin datos este mes',
            style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  const _CategoryPieChart();

  @override
  Widget build(BuildContext context) {
    final byCategory = context.watch<TransactionsProvider>().expenseByCategory;
    final categories = context.watch<CategoriesProvider>();
    final total = byCategory.values.fold<double>(0, (sum, v) => sum + v);
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 48,
        sections: [
          for (final entry in byCategory.entries)
            PieChartSectionData(
              value: entry.value,
              color: Color(categories.byId(entry.key)?.color ?? 0xFF90A4AE),
              radius: 52,
              title: '${(entry.value / total * 100).round()}%',
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _IncomePieChart extends StatelessWidget {
  const _IncomePieChart();

  @override
  Widget build(BuildContext context) {
    final transactions = context.watch<TransactionsProvider>();
    final byCategory =
        totalsByCategory(transactions.monthTransactions, type: 'income');
    final categories = context.watch<CategoriesProvider>();
    final total = byCategory.values.fold<double>(0, (sum, v) => sum + v);
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 48,
        sections: [
          for (final entry in byCategory.entries)
            PieChartSectionData(
              value: entry.value,
              color: Color(categories.byId(entry.key)?.color ?? 0xFF90A4AE),
              radius: 52,
              title: '${(entry.value / total * 100).round()}%',
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.data, required this.color});

  final List<MonthlyTotal> data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxValue =
        data.fold<double>(0, (max, t) => t.total > max ? t.total : max);
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxValue <= 0 ? 1 : maxValue * 1.2,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 44),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble()) {
                    return const SizedBox.shrink();
                  }
                  final index = value.round();
                  if (index < 0 || index >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      capitalize(formatDate(data[index].month, 'MMM')),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < data.length; i++)
                  FlSpot(i.toDouble(), data[i].total),
              ],
              isCurved: true,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                  show: true, color: color.withValues(alpha: 0.15)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashFlowChart extends StatelessWidget {
  const _CashFlowChart({required this.income, required this.expense});

  final List<MonthlyTotal> income;
  final List<MonthlyTotal> expense;

  @override
  Widget build(BuildContext context) {
    double maxValue = 0;
    for (final item in [...income, ...expense]) {
      if (item.total > maxValue) maxValue = item.total;
    }
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxValue <= 0 ? 1 : maxValue * 1.2,
          alignment: BarChartAlignment.spaceAround,
          barGroups: [
            for (var i = 0; i < income.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 4,
                barRods: [
                  BarChartRodData(
                    toY: income[i].total,
                    width: 10,
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  BarChartRodData(
                    toY: expense[i].total,
                    width: 10,
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 44),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble()) {
                    return const SizedBox.shrink();
                  }
                  final index = value.round();
                  if (index < 0 || index >= income.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      capitalize(formatDate(income[index].month, 'MMM')),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart();

  @override
  Widget build(BuildContext context) {
    final byDay = context.watch<TransactionsProvider>().expenseByDay;
    // El día 0 del mes siguiente es el último día del mes seleccionado.
    final daysInMonth = DateTime(
      context.watch<TransactionsProvider>().selectedMonth.year,
      context.watch<TransactionsProvider>().selectedMonth.month + 1,
      0,
    ).day;
    final maxValue =
        byDay.values.fold<double>(0, (max, v) => v > max ? v : max);
    return BarChart(
      BarChartData(
        maxY: maxValue <= 0 ? 1 : (maxValue * 1.2).ceilToDouble(),
        alignment: BarChartAlignment.spaceAround,
        barGroups: [
          for (var day = 1; day <= daysInMonth; day++)
            BarChartGroupData(
              x: day,
              barRods: [
                BarChartRodData(
                  toY: byDay[day] ?? 0,
                  width: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 44),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value != value.roundToDouble()) {
                  return const SizedBox.shrink();
                }
                final day = value.round();
                if (day % 5 != 0 && day != 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('$day', style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.categoryName,
    required this.color,
    required this.amount,
    required this.percent,
  });

  final String categoryName;
  final Color color;
  final String amount;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(categoryName)),
          Text('${percent.toStringAsFixed(0)}% ',
              style: Theme.of(context).textTheme.bodySmall),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _FlowLegend extends StatelessWidget {
  const _FlowLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ExpenseCalendar extends StatelessWidget {
  const _ExpenseCalendar({required this.month, required this.byDay});

  final DateTime month;
  final Map<int, double> byDay;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final maxValue =
        byDay.values.fold<double>(0, (max, v) => v > max ? v : max);
    return Column(
      children: [
        Row(
          children: [
            for (final label in ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
              Expanded(
                child: Center(
                  child: Text(label, style: const TextStyle(fontSize: 10)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: (firstWeekday - 1) + daysInMonth,
          itemBuilder: (context, index) {
            if (index < firstWeekday - 1) return const SizedBox.shrink();
            final day = index - (firstWeekday - 1) + 1;
            final amount = byDay[day] ?? 0;
            final intensity =
                maxValue <= 0 ? 0.0 : (amount / maxValue).clamp(0.0, 1.0);
            return Container(
              decoration: BoxDecoration(
                color: Colors.red.shade700.withValues(
                    alpha: amount <= 0 ? 0.06 : 0.15 + 0.75 * intensity),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text('$day', style: const TextStyle(fontSize: 10)),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _YearSummary extends StatelessWidget {
  const _YearSummary({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    return Consumer2<TransactionsProvider, SettingsProvider>(
      builder: (context, transactions, settings, _) {
        final yearTransactions =
            transactions.all.where((t) => t.date.year == year);
        final summary = summarize(yearTransactions);
        final rate =
            savingsRate(income: summary.income, expense: summary.expense);
        final income = monthlyTotals(transactions.all,
            type: 'income', lastMonth: DateTime(year, 12), months: 12);
        final expense = monthlyTotals(transactions.all,
            type: 'expense', lastMonth: DateTime(year, 12), months: 12);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: 'arrowUp',
                    label: 'Ingresos',
                    value: formatMoney(summary.income, settings.currency),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    icon: 'arrowDown',
                    label: 'Gastos',
                    value: formatMoney(summary.expense, settings.currency),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    icon: 'trendUp',
                    label: 'Ahorro',
                    value: '${(rate * 100).round()}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CashFlowChart(income: income, expense: expense),
          ],
        );
      },
    );
  }
}

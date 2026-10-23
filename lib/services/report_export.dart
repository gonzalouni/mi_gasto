import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/transaction.dart';
import '../utils/calculations.dart';
import '../utils/formatters.dart';

/// Genera el reporte del mes en PDF o Excel para compartirlo.
class ReportExport {
  static String _monthLabel(DateTime month) =>
      DateFormat("MMMM 'de' y", 'es_PE').format(month);

  static String _typeLabel(AppTransaction t) => t.isTransfer
      ? 'Transferencia'
      : t.isIncome
          ? 'Ingreso'
          : 'Gasto';

  static String _signedAmount(AppTransaction t, String currency) {
    if (t.isTransfer) return formatMoney(t.amount, currency);
    return '${t.isIncome ? '+' : '-'} ${formatMoney(t.amount, currency)}';
  }

  static Future<File> buildPdf({
    required DateTime month,
    required List<AppTransaction> transactions,
    required Map<String, String> categoryNames,
    required Map<String, String> accountNames,
    required String currency,
  }) async {
    final summary = summarize(transactions);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rate =
        savingsRate(income: summary.income, expense: summary.expense);
    final average = dailyAverage(expense: summary.expense, days: days);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text('MiGasto — Reporte de ${_monthLabel(month)}',
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Text('Ingresos: ${formatMoney(summary.income, currency)}'),
          pw.Text('Gastos: ${formatMoney(summary.expense, currency)}'),
          pw.Text('Balance: ${formatMoney(summary.balance, currency)}'),
          pw.Text('Tasa de ahorro: ${(rate * 100).round()}%'),
          pw.Text('Promedio diario: ${formatMoney(average, currency)}'),
          pw.SizedBox(height: 16),
          pw.Text('Movimientos',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Fecha', 'Tipo', 'Categoría', 'Cuenta', 'Nota', 'Monto'],
            data: [
              for (final t in transactions)
                [
                  DateFormat('dd/MM/yyyy').format(t.date),
                  _typeLabel(t),
                  categoryNames[t.categoryId] ?? '',
                  accountNames[t.accountId] ?? '',
                  t.note,
                  _signedAmount(t, currency),
                ],
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    return _writeFile('reporte_mi_gasto_${_fileStamp(month)}.pdf', bytes);
  }

  static Future<File> buildExcel({
    required DateTime month,
    required List<AppTransaction> transactions,
    required Map<String, String> categoryNames,
    required Map<String, String> accountNames,
    required String currency,
  }) async {
    final summary = summarize(transactions);
    final excel = Excel.createExcel();
    final sheet = excel['Reporte'];
    excel.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('MiGasto — Reporte de ${_monthLabel(month)}'),
    ]);
    sheet.appendRow([
      TextCellValue('Moneda'),
      TextCellValue(currency),
    ]);
    sheet.appendRow([
      TextCellValue('Ingresos'),
      DoubleCellValue(summary.income),
    ]);
    sheet.appendRow([
      TextCellValue('Gastos'),
      DoubleCellValue(summary.expense),
    ]);
    sheet.appendRow([
      TextCellValue('Balance'),
      DoubleCellValue(summary.balance),
    ]);
    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('Fecha'),
      TextCellValue('Tipo'),
      TextCellValue('Categoría'),
      TextCellValue('Cuenta'),
      TextCellValue('Nota'),
      TextCellValue('Monto'),
    ]);
    for (final t in transactions) {
      sheet.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(t.date)),
        TextCellValue(_typeLabel(t)),
        TextCellValue(categoryNames[t.categoryId] ?? ''),
        TextCellValue(accountNames[t.accountId] ?? ''),
        TextCellValue(t.note),
        DoubleCellValue(t.isIncome ? t.amount : -t.amount),
      ]);
    }

    final bytes = excel.encode();
    return _writeFile('reporte_mi_gasto_${_fileStamp(month)}.xlsx', bytes!);
  }

  static String _fileStamp(DateTime month) =>
      DateFormat('yyyy-MM').format(month);

  static Future<File> _writeFile(String name, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}

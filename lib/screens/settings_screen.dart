import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/accounts_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../services/backup_service.dart';
import '../widgets/app_icon.dart';
import 'manage_categories_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          leading: const AppIcon('moneyChange'),
          title: const Text('Moneda'),
          subtitle: Text(settings.currency),
          onTap: () => _pickCurrency(context, settings),
        ),
        ListTile(
          leading: const AppIcon('palette'),
          title: const Text('Tema'),
          subtitle: Text(_themeLabel(settings.themeMode)),
          onTap: () => _pickTheme(context, settings),
        ),
        ListTile(
          leading: const AppIcon('calendar'),
          title: const Text('Día de pago'),
          subtitle: Text('Día ${settings.payDay} de cada mes'),
          onTap: () => _pickPayDay(context, settings),
        ),
        ListTile(
          leading: const AppIcon('category'),
          title: const Text('Categorías'),
          subtitle: const Text('Añadir, editar o eliminar categorías'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const AppIcon('upload'),
          title: const Text('Exportar respaldo'),
          subtitle: const Text('Guarda todos tus datos en un archivo'),
          onTap: () => _exportBackup(context),
        ),
        ListTile(
          leading: const AppIcon('download'),
          title: const Text('Importar respaldo'),
          subtitle: const Text('Restaura datos desde un archivo'),
          onTap: () => _importBackup(context),
        ),
        const Divider(),
        const ListTile(
          leading: AppIcon('infoCircle'),
          title: Text('MiGasto'),
          subtitle: Text('Tus datos se guardan solo en este teléfono.'),
        ),
      ],
    );
  }

  Future<void> _pickCurrency(
      BuildContext context, SettingsProvider settings) async {
    const options = {
      'PEN': 'Sol peruano (S/)',
      'USD': 'Dólar (\$)',
      'EUR': 'Euro (€)',
    };
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Moneda'),
        children: [
          for (final entry in options.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(entry.key),
              child: _OptionRow(
                label: entry.value,
                selected: settings.currency == entry.key,
              ),
            ),
        ],
      ),
    );
    if (selected != null) {
      await settings.setCurrency(selected);
    }
  }

  Future<void> _pickTheme(
      BuildContext context, SettingsProvider settings) async {
    const options = {
      ThemeMode.system: 'Sistema',
      ThemeMode.light: 'Claro',
      ThemeMode.dark: 'Oscuro',
    };
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Tema'),
        children: [
          for (final entry in options.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(entry.key),
              child: _OptionRow(
                label: entry.value,
                selected: settings.themeMode == entry.key,
              ),
            ),
        ],
      ),
    );
    if (selected != null) {
      await settings.setThemeMode(selected);
    }
  }

  Future<void> _pickPayDay(
      BuildContext context, SettingsProvider settings) async {
    int day = settings.payDay;
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Día de pago'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Día $day',
                  style: Theme.of(dialogContext).textTheme.titleLarge),
              Slider(
                value: day.toDouble(),
                min: 1,
                max: 31,
                divisions: 30,
                label: '$day',
                onChanged: (value) => setState(() => day = value.round()),
              ),
              const Text('Tu mes presupuestal empieza este día.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(day),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await settings.setPayDay(selected);
    }
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Oscuro';
      case ThemeMode.system:
        return 'Sistema';
    }
  }

  Future<void> _exportBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await BackupService.createBackupFile();
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'Respaldo MiGasto'),
      );
    } catch (error) {
      messenger
          .showSnackBar(SnackBar(content: Text('No se pudo exportar: $error')));
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) return;
    final path = files.first.path;
    if (path == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importar respaldo'),
        content: const Text(
            'Se reemplazarán todos los datos actuales por los del archivo. ¿Continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final transactions = context.read<TransactionsProvider>();
    final accounts = context.read<AccountsProvider>();
    final categories = context.read<CategoriesProvider>();
    final settings = context.read<SettingsProvider>();
    try {
      await BackupService.restoreFromFile(path);
      await transactions.load();
      await accounts.load();
      await categories.load();
      await settings.load();
      messenger
          .showSnackBar(const SnackBar(content: Text('Respaldo restaurado')));
    } catch (error) {
      messenger
          .showSnackBar(SnackBar(content: Text('No se pudo importar: $error')));
    }
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        if (selected) const AppIcon('check', size: 20),
      ],
    );
  }
}

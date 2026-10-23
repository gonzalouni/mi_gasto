import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reicon_flutter/reicon_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../providers/categories_provider.dart';
import '../widgets/app_icon.dart';

class ManageCategoriesScreen extends StatelessWidget {
  const ManageCategoriesScreen({super.key});

  static const _palette = [
    0xFFE57373,
    0xFFFFB74D,
    0xFFFFD54F,
    0xFF81C784,
    0xFF4DB6AC,
    0xFF64B5F6,
    0xFF7986CB,
    0xFFBA68C8,
    0xFFF06292,
    0xFF90A4AE,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const AppIcon('arrowLeft'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Categorías'),
      ),
      body: Consumer<CategoriesProvider>(
        builder: (context, provider, _) {
          final expenses = provider.byType('expense');
          final incomes = provider.byType('income');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionHeader(context, 'Gastos'),
              _categoryList(context, provider, expenses),
              _sectionHeader(context, 'Ingresos'),
              _categoryList(context, provider, incomes),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(context),
        child: const AppIcon('add'),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _categoryList(BuildContext context, CategoriesProvider provider,
          List<TxCategory> categories) =>
      Card(
        child: Column(
          children: [
            for (final category in categories)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(category.color).withValues(alpha: 0.2),
                  child: AppIcon(category.icon,
                      size: 20, color: Color(category.color)),
                ),
                title: Text(category.name),
                trailing: const AppIcon('caretRight', size: 20),
                onTap: () =>
                    _showCategoryDialog(context, category: category),
              ),
          ],
        ),
      );

  Future<String?> _pickIcon(BuildContext context, String current) =>
      showDialog<String>(
        context: context,
        builder: (_) => _IconPickerDialog(current: current),
      );

  Future<void> _showCategoryDialog(BuildContext context,
      {TxCategory? category}) async {
    final nameController = TextEditingController(text: category?.name);
    String icon = category?.icon ?? 'moreCircle';
    int color = category?.color ?? _palette.first;
    String type = category?.type ?? 'expense';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(
              category == null ? 'Nueva categoría' : 'Editar categoría'),
          content: SingleChildScrollView(
            child: Column(
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
                  items: const [
                    DropdownMenuItem(value: 'expense', child: Text('Gasto')),
                    DropdownMenuItem(value: 'income', child: Text('Ingreso')),
                  ],
                  onChanged: (value) =>
                      setState(() => type = value ?? 'expense'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AppIcon(icon, size: 28),
                  title: const Text('Ícono'),
                  subtitle: Text(icon),
                  trailing: const AppIcon('caretRight', size: 20),
                  onTap: () async {
                    final picked = await _pickIcon(dialogContext, icon);
                    if (picked != null) setState(() => icon = picked);
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final swatch in _palette)
                      GestureDetector(
                        onTap: () => setState(() => color = swatch),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(swatch),
                          child: color == swatch
                              ? const AppIcon('check',
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (category != null)
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
              onPressed: () => Navigator.of(dialogContext).pop({
                'name': nameController.text.trim(),
                'icon': icon,
                'color': color,
                'type': type,
              }),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !context.mounted) return;
    final provider = context.read<CategoriesProvider>();

    if (result['delete'] == true) {
      final inUse = await provider.isInUse(category!.id);
      if (!context.mounted) return;
      if (inUse) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se puede eliminar: tiene movimientos')));
        return;
      }
      await provider.remove(category.id);
      return;
    }

    final name = result['name'] as String;
    if (name.isEmpty) return;
    if (category == null) {
      await provider.add(TxCategory(
        id: const Uuid().v4(),
        name: name,
        icon: result['icon'] as String,
        color: result['color'] as int,
        type: result['type'] as String,
      ));
    } else {
      await provider.update(TxCategory(
        id: category.id,
        name: name,
        icon: result['icon'] as String,
        color: result['color'] as int,
        type: result['type'] as String,
      ));
    }
  }
}

class _IconPickerDialog extends StatefulWidget {
  const _IconPickerDialog({required this.current});

  final String current;

  @override
  State<_IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<_IconPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.toLowerCase();
    final names = Reicon.outline.names
        .where((name) => name.toLowerCase().contains(query))
        .toList()
      ..sort();
    return AlertDialog(
      title: const Text('Elegir ícono'),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: AppIcon('search', size: 18),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  maxWidth: 26,
                  maxHeight: 24,
                ),
                hintText: 'Buscar (ej. car, food, home)',
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 72,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: names.length,
                itemBuilder: (context, index) {
                  final name = names[index];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(name),
                    borderRadius: BorderRadius.circular(8),
                    child: Tooltip(
                      message: name,
                      child: Center(
                        child: AppIcon(
                          name,
                          size: 26,
                          color: name == widget.current
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

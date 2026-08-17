import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/category_model.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../presentation/providers/category_provider.dart';
import '../../../../presentation/providers/trip_provider.dart';
import '../../../../presentation/providers/authentication_provider.dart';

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends ConsumerState<CategoryManagementScreen> {
  final _nameCtrl = TextEditingController();
  int _selectedIcon = Icons.category_rounded.codePoint;
  int _selectedColor = Colors.blue.toARGB32();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';
    final categories = ref.watch(mergedCategoriesProvider(tripId));
    final tripAsync = ref.watch(tripByIdProvider(tripId));
    final trip = tripAsync.valueOrNull;
    final isAdmin = trip != null && ref.watch(authProvider).user?.uid == trip.adminId;

    return Scaffold(
      appBar: CustomAppBar(title: 'Categories'),
      body: categories.isEmpty
          ? const Center(child: Text('No categories'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: categories.map((cat) => _buildCategoryCard(cat, colorScheme, isAdmin, tripId)).toList(),
            ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showAddDialog(context, colorScheme, tripId),
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  Widget _buildCategoryCard(CategoryModel cat, ColorScheme colorScheme, bool isAdmin, String tripId) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (cat.isDefault)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text('default', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cat.budget > 0 ? 'Budget: ${cat.budget.toStringAsFixed(2)}' : 'No budget set',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (isAdmin)
                  PopupMenuButton<String>(
                    onSelected: (v) => _handleAction(v, cat, context, colorScheme, tripId),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'budget', child: ListTile(
                        leading: Icon(Icons.attach_money_rounded, size: 20),
                        title: Text('Set Budget'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      )),
                      if (!cat.isDefault)
                        const PopupMenuItem(value: 'archive', child: ListTile(
                          leading: Icon(Icons.archive_rounded, size: 20),
                          title: Text('Archive'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        )),
                    ],
                  ),
              ],
            ),
            if (cat.isArchived)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Archived', style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleAction(String action, CategoryModel cat, BuildContext context, ColorScheme colorScheme, String tripId) {
    switch (action) {
      case 'budget':
        _showBudgetDialog(context, cat, colorScheme);
      case 'archive':
        _archiveCategory(cat, tripId);
    }
  }

  void _showBudgetDialog(BuildContext context, CategoryModel cat, ColorScheme colorScheme) {
    final ctrl = TextEditingController(text: cat.budget > 0 ? cat.budget.toString() : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Budget'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Budget amount', prefixText: '\$ '),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text.trim());
              if (amount == null || amount < 0) return;
              final updated = cat.copyWith(budget: amount);
              await ref.read(categoryServiceProvider).updateCategory(updated);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _archiveCategory(CategoryModel cat, String tripId) async {
    await ref.read(categoryServiceProvider).archiveCategory(cat.categoryId);
    if (mounted) SnackbarHelper.showSuccess(context, '${cat.name} archived');
  }

  void _showAddDialog(BuildContext context, ColorScheme colorScheme, String tripId) {
    _nameCtrl.clear();
    _selectedIcon = Icons.category_rounded.codePoint;
    _selectedColor = Colors.blue.toARGB32();

    final icons = [
      Icons.restaurant_rounded, Icons.directions_car_rounded, Icons.hotel_rounded,
      Icons.sports_esports_rounded, Icons.shopping_bag_rounded, Icons.build_rounded,
      Icons.medical_services_rounded, Icons.movie_rounded, Icons.flight_rounded,
      Icons.pets_rounded, Icons.school_rounded, Icons.fitness_center_rounded,
      Icons.water_drop_rounded, Icons.eco_rounded, Icons.coffee_rounded,
    ];

    final colors = [
      Colors.orange, Colors.blue, Colors.purple, Colors.teal, Colors.pink,
      Colors.brown, Colors.red, Colors.indigo, Colors.green, Colors.cyan,
      Colors.amber, Colors.deepOrange, Colors.lime, Colors.yellow, Colors.deepPurple,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Custom Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Category Name'),
                ),
                const SizedBox(height: 16),
                const Text('Icon', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: icons.map((icon) {
                    final selected = icon.codePoint == _selectedIcon;
                    return GestureDetector(
                      onTap: () => setDialogState(() => _selectedIcon = icon.codePoint),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: selected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: selected ? Border.all(color: colorScheme.primary, width: 2) : null,
                        ),
                        child: Icon(icon, size: 20, color: selected ? colorScheme.primary : null),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((c) {
                    final selected = c.toARGB32() == _selectedColor;
                    return GestureDetector(
                      onTap: () => setDialogState(() => _selectedColor = c.toARGB32()),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(8),
                          border: selected ? Border.all(color: colorScheme.onSurface, width: 2.5) : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final name = _nameCtrl.text.trim();
                if (name.isEmpty) return;
                await ref.read(categoryServiceProvider).addCategory(
                  tripId: tripId,
                  name: name,
                  iconCodePoint: _selectedIcon,
                  colorValue: _selectedColor,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}



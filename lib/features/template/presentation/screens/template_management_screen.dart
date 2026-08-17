import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/expense_template_model.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../presentation/providers/template_provider.dart';
import '../../../../presentation/providers/category_provider.dart';
import '../../../../presentation/providers/authentication_provider.dart';

class TemplateManagementScreen extends ConsumerStatefulWidget {
  const TemplateManagementScreen({super.key});

  @override
  ConsumerState<TemplateManagementScreen> createState() => _TemplateManagementScreenState();
}

class _TemplateManagementScreenState extends ConsumerState<TemplateManagementScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final templatesAsync = ref.watch(userTemplatesProvider);
    final templates = templatesAsync.valueOrNull ?? [];
    final filtered = _searchQuery.isEmpty
        ? templates
        : templates.where((t) => t.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    final globals = filtered.where((t) => t.tripId == null).toList();
    final tripSpecific = filtered.where((t) => t.tripId != null).toList();

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Expense Templates',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showCreateDialog(context, colorScheme, null),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search templates...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: templatesAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _buildEmptyState(colorScheme)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                        children: [
                          if (globals.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('Global Templates',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                            ),
                            ...globals.map((t) => _buildTemplateCard(t, colorScheme)),
                            const SizedBox(height: 16),
                          ],
                          if (tripSpecific.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('Trip Templates',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                            ),
                            ...tripSpecific.map((t) => _buildTemplateCard(t, colorScheme)),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 72, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No templates yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('Create reusable expense templates', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(ExpenseTemplateModel template, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.description_outlined, color: colorScheme.primary, size: 20),
        ),
        title: Text(template.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${template.category}${template.splitType == 'equal' ? ' · Equal split' : ' · Custom split'}${template.notes != null ? ' · ${template.notes!.length > 30 ? '${template.notes!.substring(0, 30)}...' : template.notes!}' : ''}',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                template.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: template.favorite ? Colors.amber : null,
                size: 20,
              ),
              onPressed: () {
                ref.read(templateServiceProvider).toggleFavorite(template.templateId, !template.favorite);
              },
            ),
            PopupMenuButton<String>(
              onSelected: (v) => _handleTemplateAction(v, template, colorScheme),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: ListTile(
                  leading: Icon(Icons.edit_outlined, size: 20),
                  title: Text('Edit'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )),
                const PopupMenuItem(value: 'duplicate', child: ListTile(
                  leading: Icon(Icons.copy_rounded, size: 20),
                  title: Text('Duplicate'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )),
                const PopupMenuItem(value: 'delete', child: ListTile(
                  leading: Icon(Icons.delete_outlined, size: 20, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleTemplateAction(String action, ExpenseTemplateModel template, ColorScheme colorScheme) {
    switch (action) {
      case 'edit':
        _showCreateDialog(context, colorScheme, template);
      case 'duplicate':
        ref.read(templateServiceProvider).duplicateTemplate(template);
        SnackbarHelper.showSuccess(context, 'Template duplicated');
      case 'delete':
        _deleteTemplate(template);
    }
  }

  Future<void> _deleteTemplate(ExpenseTemplateModel template) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Template',
      message: 'Delete "${template.name}"?',
      confirmLabel: 'Delete',
      icon: Icons.delete_rounded,
    );
    if (confirmed == true) {
      await ref.read(templateServiceProvider).deleteTemplate(template.templateId);
      if (mounted) SnackbarHelper.showSuccess(context, 'Template deleted');
    }
  }

  void _showCreateDialog(BuildContext context, ColorScheme colorScheme, ExpenseTemplateModel? existing) {
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'];
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String category = existing?.category ?? 'Food';
    String splitType = existing?.splitType ?? 'equal';
    bool isTripSpecific = existing != null ? existing.tripId != null : false;
    final categories = ref.read(activeCategoriesProvider(tripId ?? ''));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Edit Template' : 'New Template'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Template Name *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category', isDense: true),
                  items: categories.map((c) => DropdownMenuItem(
                    value: c.name,
                    child: Row(children: [Icon(c.icon, size: 16, color: c.color), const SizedBox(width: 8), Text(c.name)]),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => category = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: splitType,
                  decoration: const InputDecoration(labelText: 'Split Type', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'equal', child: Text('Equal Split')),
                    DropdownMenuItem(value: 'custom', child: Text('Custom Split')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => splitType = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Default Notes (optional)'),
                  maxLines: 2,
                ),
                if (existing == null && tripId != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isTripSpecific,
                        onChanged: (v) => setDialogState(() => isTripSpecific = v ?? false),
                      ),
                      const Text('Trip-specific template'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final service = ref.read(templateServiceProvider);
                final user = ref.read(authProvider).user;
                if (user == null) return;

                if (existing != null) {
                  await service.updateTemplate(existing.copyWith(
                    name: name,
                    category: category,
                    splitType: splitType,
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  ));
                } else {
                  await service.createTemplate(
                    userId: user.uid,
                    tripId: isTripSpecific ? tripId : null,
                    name: name,
                    category: category,
                    splitType: splitType,
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(existing != null ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}

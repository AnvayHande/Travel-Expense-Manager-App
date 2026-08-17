import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/models/expense_model.dart';
import '../../../../core/models/trip_model.dart';
import '../../../../core/models/split_detail.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../presentation/providers/expense_provider.dart';
import '../../../../presentation/providers/trip_provider.dart';
import '../../../../presentation/providers/authentication_provider.dart';
import '../../../../presentation/providers/firebase_providers.dart';
import '../../../../presentation/providers/receipt_provider.dart';
import '../../../../presentation/providers/activity_provider.dart';
import '../../../../presentation/providers/category_provider.dart';
import '../../../../presentation/providers/template_provider.dart';
import '../../../../presentation/providers/draft_expense_provider.dart';
import '../../../../core/models/expense_template_model.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _selectedCategory = 'Food';
  String? _paidBy;
  String _splitType = 'equal';
  List<String> _splitBetween = [];
  final Map<String, TextEditingController> _splitCtrls = {};
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;
  bool _dataLoaded = false;

  TripModel? _trip;
  ExpenseModel? _editExpense;
  Map<String, String> _participantNames = {};

  Timer? _autoSaveTimer;

  XFile? _receiptImage;
  String? _receiptUrl;
  bool _isUploadingReceipt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  @override
  void dispose() {
    _cancelAutoSaveTimer();
    _saveDraft();
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _splitCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initData() {
    if (_dataLoaded) return;

    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';
    _editExpense = routeState.extra as ExpenseModel?;

    final tripAsync = ref.read(tripByIdProvider(tripId));
    final tripValue = tripAsync.valueOrNull;
    if (tripValue == null) return;

    _trip = tripValue;
    _loadParticipantNames(tripValue.participants);

    if (_editExpense != null) {
      _nameCtrl.text = _editExpense!.expenseName;
      _amountCtrl.text = _editExpense!.amount.toString();
      _notesCtrl.text = _editExpense!.notes ?? '';
      _selectedCategory = _editExpense!.category;
      _paidBy = _editExpense!.paidBy;
      _splitType = _editExpense!.splitType;
      _splitBetween = List.from(_editExpense!.splitBetween);
      for (final d in _editExpense!.splitDetails) {
        final ctrl = TextEditingController(
          text: d.amount?.toStringAsFixed(2) ??
              d.percentage?.toStringAsFixed(1) ??
              d.shares?.toString() ??
              '',
        );
        _splitCtrls[d.userId] = ctrl;
      }
      _selectedDate = _editExpense!.createdAt;
    } else {
      final user = ref.read(authProvider).user;
      _paidBy = user?.uid;
      _splitBetween = List.from(tripValue.participants);
      _initSplitCtrls(tripValue.participants);
    }

    _dataLoaded = true;

    if (_editExpense == null) {
      _checkForDraft(tripId);
    }

    _startAutoSaveTimer();
  }

  Future<void> _checkForDraft(String tripId) async {
    final notifier = ref.read(draftExpenseProvider.notifier);
    await notifier.checkForDraft(tripId);
    final state = ref.read(draftExpenseProvider);
    if (!state.hasDraft || state.draftData == null) return;

    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Unfinished Expense'),
        content: const Text('An unfinished expense was found.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard Draft'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'continue'),
            child: const Text('Continue Editing'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (result == 'continue') {
      _restoreDraft(state.draftData!);
    } else if (result == 'discard') {
      await notifier.discardDraft(tripId);
    }
  }

  void _restoreDraft(Map<String, dynamic> draft) {
    _nameCtrl.text = draft['expenseName'] as String? ?? '';
    _amountCtrl.text = draft['amount'] as String? ?? '';
    _selectedCategory = draft['category'] as String? ?? 'Food';
    _paidBy = draft['paidBy'] as String?;
    _splitType = draft['splitType'] as String? ?? 'equal';
    _splitBetween = (draft['splitBetween'] as List<dynamic>?)?.cast<String>() ?? [];
    _notesCtrl.text = draft['notes'] as String? ?? '';
    final dateMillis = draft['dateMillis'] as int?;
    if (dateMillis != null) {
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(dateMillis);
    }
    final splitValues = draft['splitValues'] as Map<String, dynamic>?;
    if (splitValues != null) {
      for (final entry in splitValues.entries) {
        final text = entry.value as String? ?? '';
        _splitCtrls[entry.key] = TextEditingController(text: text);
      }
    }
    setState(() {});
  }

  void _startAutoSaveTimer() {
    _cancelAutoSaveTimer();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _saveDraft();
    });
  }

  void _cancelAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  void _saveDraft() {
    if (_trip == null || _editExpense != null) return;
    final splitValues = <String, String>{};
    for (final entry in _splitCtrls.entries) {
      if (entry.value.text.isNotEmpty) {
        splitValues[entry.key] = entry.value.text;
      }
    }
    ref.read(draftExpenseProvider.notifier).saveDraft(
      tripId: _trip!.tripId,
      expenseName: _nameCtrl.text,
      amount: _amountCtrl.text,
      category: _selectedCategory,
      paidBy: _paidBy,
      splitType: _splitType,
      splitBetween: _splitBetween,
      splitValues: splitValues,
      notes: _notesCtrl.text,
      dateMillis: _selectedDate.millisecondsSinceEpoch,
    );
  }

  void _initSplitCtrls(List<String> participants) {
    for (final uid in participants) {
      _splitCtrls.putIfAbsent(uid, () => TextEditingController());
    }
  }


  Future<void> _loadParticipantNames(List<String> uids) async {
    final firestore = ref.read(firestoreServiceProvider);
    final map = <String, String>{};
    for (final uid in uids) {
      try {
        final doc = await firestore.getDocument(
          collection: firestore.users,
          documentId: uid,
        );
        final data = doc.data() as Map<String, dynamic>;
        map[uid] = data['name'] as String? ?? uid;
      } catch (_) {
        map[uid] = uid;
      }
    }
    if (mounted) {
      setState(() => _participantNames = map);
    }
  }

  String _displayName(String uid) =>
      _participantNames[uid] ??
      (uid.length > 8 ? '${uid.substring(0, 8)}...' : uid);

  void _applyTemplate(ExpenseTemplateModel template, String tripId) {
    _nameCtrl.text = template.name;
    _selectedCategory = template.category;
    _notesCtrl.text = template.notes ?? '';
    _splitType = template.splitType;

    if (template.splitType == 'equal' && _trip != null) {
      _splitBetween = List.from(_trip!.participants);
    } else if (template.splitType == 'paidOnly') {
      _splitBetween = _paidBy != null ? [_paidBy!] : [];
    }

    ref.read(templateServiceProvider).recordUsage(template.templateId);
    setState(() {});
    _saveDraft();
  }

  Widget _buildQuickAddSection(
      List<ExpenseTemplateModel> templates,
      List<ExpenseTemplateModel> recentlyUsed,
      ColorScheme colorScheme,
      String tripId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recentlyUsed.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.history_rounded, size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('Recently Used',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recentlyUsed.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _buildTemplateChip(recentlyUsed[i], colorScheme, tripId),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (templates.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.description_outlined, size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('Templates',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
              const Spacer(),
              GestureDetector(
                onTap: () => context.pushNamed(
                  'templateManagement',
                  pathParameters: {'tripId': tripId},
                ),
                child: Text('Manage', style: TextStyle(fontSize: 12, color: colorScheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: templates.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _buildTemplateChip(templates[i], colorScheme, tripId),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTemplateChip(ExpenseTemplateModel template, ColorScheme colorScheme, String tripId) {
    final categories = ref.watch(activeCategoriesProvider(tripId));
    final cat = categories.where((c) => c.name == template.category).firstOrNull;

    return GestureDetector(
      onTap: () => _applyTemplate(template, tripId),
      child: Card(
        margin: EdgeInsets.zero,
        child: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(cat?.icon ?? Icons.receipt_long_rounded, size: 14, color: cat?.color ?? Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(template.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.attach_money_rounded, size: 12, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(template.category,
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (template.favorite) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';
    final categories = ref.watch(activeCategoriesProvider(tripId));
    final isEditing = _editExpense != null;
    final templates = ref.watch(tripTemplatesProvider(tripId));
    final recentlyUsed = ref.watch(recentlyUsedTemplatesProvider(tripId));

    if (categories.isNotEmpty && _selectedCategory == 'Food' && !categories.any((c) => c.name == 'Food')) {
      _selectedCategory = categories.first.name;
    }

    _initData();

    final isReadOnly = _trip != null && !_trip!.isActive;

    if (_dataLoaded && isReadOnly) {
      return Scaffold(
        appBar: CustomAppBar(
          title: isEditing ? 'Edit Expense' : 'Add Expense',
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 64, color: colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  'Trip is completed',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cannot add or edit expenses in a completed trip.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: isEditing ? 'Edit Expense' : 'Add Expense',
      ),
      body: !_dataLoaded
          ? const LoadingIndicator(message: 'Loading...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isEditing, colorScheme),
                    if (!isEditing) ...[
                      _buildQuickAddSection(templates, recentlyUsed, colorScheme, tripId),
                      const SizedBox(height: 24),
                    ],
                    const SizedBox(height: 24),
                    _buildNameField(),
                    const SizedBox(height: 16),
                    _buildAmountField(),
                    const SizedBox(height: 16),
                    _buildCategoryDropdown(colorScheme),
                    const SizedBox(height: 16),
                    _buildPaidByDropdown(colorScheme),
                    const SizedBox(height: 16),
                    _buildSplitTypeSelector(colorScheme),
                    const SizedBox(height: 16),
                    _buildSplitInputSection(colorScheme),
                    const SizedBox(height: 16),
                    _buildDatePicker(colorScheme),
                    const SizedBox(height: 16),
                    _buildNotesField(),
                    const SizedBox(height: 16),
                    _buildReceiptSection(colorScheme),
                    const SizedBox(height: 32),
                    PrimaryButton(
                      label: isEditing ? 'Update Expense' : 'Add Expense',
                      isLoading: _isSubmitting || _isUploadingReceipt,
                      onPressed: () => _submit(tripId, isEditing),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(bool isEditing, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isEditing ? Icons.edit_outlined : Icons.add_card_rounded,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? 'Edit Expense' : 'New Expense',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              _trip?.tripName ?? '',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameCtrl,
      decoration: const InputDecoration(
        labelText: 'Expense Name *',
        prefixIcon: Icon(Icons.receipt_outlined),
      ),
      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
      textInputAction: TextInputAction.next,
      onChanged: (_) => _saveDraft(),
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountCtrl,
      decoration: const InputDecoration(
        labelText: 'Amount *',
        prefixIcon: Icon(Icons.attach_money_rounded),
        hintText: '0.00',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Required';
        final amount = double.tryParse(v.trim());
        if (amount == null || amount <= 0) return 'Enter a valid amount';
        return null;
      },
      textInputAction: TextInputAction.done,
      onChanged: (_) => _saveDraft(),
    );
  }

  Widget _buildCategoryDropdown(ColorScheme colorScheme) {
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';
    final categories = ref.watch(activeCategoriesProvider(tripId));

    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Category',
        prefixIcon: Icon(Icons.category_rounded),
      ),
      items: categories.map((cat) {
        return DropdownMenuItem(
          value: cat.name,
          child: Row(
            children: [
              Icon(cat.icon, size: 18, color: cat.color),
              const SizedBox(width: 10),
              Text(cat.name),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) {
          setState(() => _selectedCategory = v);
          _saveDraft();
        }
      },
    );
  }

  Widget _buildPaidByDropdown(ColorScheme colorScheme) {
    final participants = _trip?.participants ?? [];

    return DropdownButtonFormField<String>(
      initialValue: _paidBy,
      decoration: const InputDecoration(
        labelText: 'Paid By',
        prefixIcon: Icon(Icons.person_outlined),
      ),
      items: participants.map((uid) {
        return DropdownMenuItem(
          value: uid,
          child: Text(_displayName(uid)),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) {
          setState(() => _paidBy = v);
          _saveDraft();
        }
      },
      validator: (v) => v == null ? 'Select who paid' : null,
    );
  }

  Widget _buildSplitTypeSelector(ColorScheme colorScheme) {
    const splitTypes = [
      ('equal', 'Equal', Icons.people_alt_rounded),
      ('exact', 'Exact', Icons.pin_rounded),
      ('percentage', 'Percent', Icons.percent_rounded),
      ('shares', 'Shares', Icons.equalizer_rounded),
      ('paidOnly', 'Paid Only', Icons.person_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Split Type',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: splitTypes.map((entry) {
              final (key, label, icon) = entry;
              final selected = _splitType == key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(icon, size: 16),
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _splitType = key;
                      if (key == 'paidOnly') {
                        _splitBetween = _paidBy != null ? [_paidBy!] : [];
                      } else if (key == 'equal' && _trip != null) {
                        _splitBetween = List.from(_trip!.participants);
                      }
                    });
                    _saveDraft();
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSplitInputSection(ColorScheme colorScheme) {
    final participants = _trip?.participants ?? [];
    if (participants.isEmpty) return const SizedBox.shrink();

    if (_splitType == 'paidOnly') {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('This expense will not be split.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    if (_splitType == 'equal') {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.people_outlined, size: 20, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text('Split Between',
                      style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                  const Spacer(),
                  Text('${_splitBetween.length} / ${participants.length}',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                ],
              ),
              const Divider(height: 20),
              ...participants.map((uid) {
                final isSelected = _splitBetween.contains(uid);
                return CheckboxListTile(
                  value: isSelected,
                  title: Text(_displayName(uid)),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (_) {
                    setState(() {
                      if (isSelected) {
                        _splitBetween.remove(uid);
                      } else {
                        _splitBetween.add(uid);
                      }
                    });
                    _saveDraft();
                  },
                );
              }),
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.select_all_rounded, size: 18),
                    label: const Text('Select All'),
                    onPressed: () {
                      setState(() => _splitBetween = List.from(participants));
                      _saveDraft();
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.deselect_rounded, size: 18),
                    label: const Text('Clear'),
                    onPressed: () {
                      setState(() => _splitBetween.clear());
                      _saveDraft();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final amountStr = _amountCtrl.text.trim();
    final totalAmount = double.tryParse(amountStr) ?? 0;
    final hint = _splitType == 'exact'
        ? 'Amount each owes'
        : _splitType == 'percentage'
            ? 'Percentage %'
            : 'Number of shares';

    final suffix = _splitType == 'percentage' ? ' %' : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people_outlined, size: 20, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Split Details',
                    style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
              ],
            ),
            const SizedBox(height: 4),
            Text(hint,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
            const Divider(height: 20),
            ...participants.map((uid) {
              _splitCtrls.putIfAbsent(uid, () => TextEditingController());
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(_displayName(uid),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _splitCtrls[uid],
                        decoration: InputDecoration(
                          isDense: true,
                          suffixText: suffix,
                          hintText: '0',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) {
                          setState(() {});
                          _saveDraft();
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (_splitType == 'exact' && totalAmount > 0)
              _buildSplitTotalCheck(totalAmount, colorScheme),
            if (_splitType == 'percentage')
              _buildPercentageCheck(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitTotalCheck(double totalAmount, ColorScheme colorScheme) {
    double entered = 0;
    for (final uid in _splitBetween) {
      entered += double.tryParse(_splitCtrls[uid]?.text ?? '') ?? 0;
    }
    final diff = (totalAmount - entered).abs();

    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Total: ${entered.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: diff < 0.01 ? Colors.green : colorScheme.onSurfaceVariant)),
            const SizedBox(width: 8),
            Text('/ ${totalAmount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
          ],
        ),
        if (diff >= 0.01)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Amounts must total ${totalAmount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 11, color: colorScheme.error)),
          ),
      ],
    );
  }

  Widget _buildPercentageCheck(ColorScheme colorScheme) {
    double totalPct = 0;
    for (final uid in _splitBetween) {
      totalPct += double.tryParse(_splitCtrls[uid]?.text ?? '') ?? 0;
    }
    final diff = (100 - totalPct).abs();

    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Total: ${totalPct.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, color: diff < 0.5 ? Colors.green : colorScheme.onSurfaceVariant)),
            const SizedBox(width: 8),
            Text('/ 100%',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
          ],
        ),
        if (diff >= 0.5)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Percentages must total 100%',
                style: TextStyle(fontSize: 11, color: colorScheme.error)),
          ),
      ],
    );
  }

  Widget _buildDatePicker(ColorScheme colorScheme) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) {
          setState(() => _selectedDate = picked);
          _saveDraft();
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date',
          prefixIcon: Icon(Icons.calendar_today_outlined),
        ),
        child: Text(DateFormatter.formatDate(_selectedDate)),
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesCtrl,
      decoration: const InputDecoration(
        labelText: 'Notes (optional)',
        prefixIcon: Icon(Icons.notes_rounded),
      ),
      maxLines: 3,
      textInputAction: TextInputAction.newline,
      onChanged: (_) => _saveDraft(),
    );
  }

  Widget _buildReceiptSection(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Receipt',
                    style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                const Spacer(),
                if (_receiptUrl != null || _receiptImage != null)
                  TextButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Remove'),
                    onPressed: _removeReceipt,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isUploadingReceipt)
              Column(
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text('Uploading receipt...',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                ],
              )
            else if (_receiptImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_receiptImage!.path),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else if (_receiptUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _receiptUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_rounded, color: colorScheme.onSurfaceVariant),
                            const SizedBox(height: 4),
                            Text('Failed to load',
                                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Camera'),
                      onPressed: () => _pickReceipt(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('Gallery'),
                      onPressed: () => _pickReceipt(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final notifier = ref.read(receiptProvider.notifier);
    final XFile? image;
    if (source == ImageSource.camera) {
      image = await notifier.pickFromCamera();
    } else {
      image = await notifier.pickFromGallery();
    }
    if (image == null) return;

    setState(() {
      _receiptImage = image;
      _isUploadingReceipt = true;
    });

    final tripId = _trip?.tripId ?? '';
    final expenseId = _editExpense?.expenseId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';

    final url = await notifier.uploadReceipt(
      image: image,
      tripId: tripId,
      expenseId: expenseId,
    );

    if (mounted) {
      setState(() {
        _isUploadingReceipt = false;
        if (url != null) {
          _receiptUrl = url;
        } else {
          _receiptImage = null;
          SnackbarHelper.showError(context, 'Failed to upload receipt.');
        }
      });
    }
  }

  void _removeReceipt() {
    setState(() {
      _receiptImage = null;
      _receiptUrl = null;
    });
  }

  String? _validateSplit() {
    if (_splitType == 'paidOnly') return null;
    if (_splitBetween.isEmpty) return 'Select at least one person for split.';

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    if (_splitType == 'exact') {
      double total = 0;
      for (final uid in _splitBetween) {
        total += double.tryParse(_splitCtrls[uid]?.text ?? '') ?? 0;
      }
      if ((amount - total).abs() > 0.01) {
        return 'Split amounts must total ${amount.toStringAsFixed(2)}.';
      }
    }

    if (_splitType == 'percentage') {
      double total = 0;
      for (final uid in _splitBetween) {
        total += double.tryParse(_splitCtrls[uid]?.text ?? '') ?? 0;
      }
      if ((100 - total).abs() > 0.5) {
        return 'Percentages must total 100%.';
      }
    }

    if (_splitType == 'shares') {
      for (final uid in _splitBetween) {
        final shares = int.tryParse(_splitCtrls[uid]?.text ?? '') ?? 0;
        if (shares <= 0) return 'Shares must be greater than zero.';
      }
    }

    return null;
  }

  List<SplitDetail> _buildSplitDetails() {
    switch (_splitType) {
      case 'exact':
        return _splitBetween.map((uid) => SplitDetail(
          userId: uid,
          amount: double.tryParse(_splitCtrls[uid]?.text ?? '') ?? 0,
        )).toList();
      case 'percentage':
        return _splitBetween.map((uid) => SplitDetail(
          userId: uid,
          percentage: double.tryParse(_splitCtrls[uid]?.text ?? '') ?? 0,
        )).toList();
      case 'shares':
        return _splitBetween.map((uid) => SplitDetail(
          userId: uid,
          shares: int.tryParse(_splitCtrls[uid]?.text ?? '') ?? 1,
        )).toList();
      case 'paidOnly':
        return [];
      case 'equal':
      default:
        return _splitBetween.map((uid) => SplitDetail(userId: uid)).toList();
    }
  }

  Future<void> _submit(String tripId, bool isEditing) async {
    if (!_formKey.currentState!.validate()) return;

    final splitError = _validateSplit();
    if (splitError != null) {
      SnackbarHelper.showError(context, splitError);
      return;
    }

    setState(() => _isSubmitting = true);

    final amount = double.parse(_amountCtrl.text.trim());
    final splitDetails = _buildSplitDetails();

    if (isEditing) {
      final updated = _editExpense!.copyWith(
        expenseName: _nameCtrl.text.trim(),
        amount: amount,
        paidBy: _paidBy,
        splitType: _splitType,
        splitDetails: splitDetails,
        category: _selectedCategory,
        createdAt: _selectedDate,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        receiptUrl: _receiptUrl,
      );
      final success = await ref.read(expenseProvider.notifier).updateExpense(updated);

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (success) {
          final currentUser = ref.read(authProvider).user;
          if (currentUser != null) {
            ref.read(activityServiceProvider).logActivity(
              tripId: tripId,
              userId: currentUser.uid,
              userName: currentUser.name,
              actionType: 'expense_edited',
              message: 'edited "${updated.expenseName}" expense',
            );
          }
          SnackbarHelper.showSuccess(context, 'Expense updated!');
          ref.read(draftExpenseProvider.notifier).deleteDraft(tripId);
          context.pop();
        } else {
          SnackbarHelper.showError(
            context,
            ref.read(expenseProvider).error ?? 'Failed to update expense.',
          );
        }
      }
    } else {
      final expense = await ref.read(expenseProvider.notifier).addExpense(
        tripId: tripId,
        expenseName: _nameCtrl.text.trim(),
        amount: amount,
        paidBy: _paidBy ?? '',
        splitType: _splitType,
        splitDetails: splitDetails,
        category: _selectedCategory,
        createdAt: _selectedDate,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        receiptUrl: _receiptUrl,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (expense != null) {
          final currentUser = ref.read(authProvider).user;
          if (currentUser != null) {
            ref.read(activityServiceProvider).logActivity(
              tripId: tripId,
              userId: currentUser.uid,
              userName: currentUser.name,
              actionType: 'expense_added',
              message: 'added "${expense.expenseName}" expense',
            );
          }
          SnackbarHelper.showSuccess(context, 'Expense added!');
          ref.read(draftExpenseProvider.notifier).deleteDraft(tripId);
          context.pop();
        } else {
          SnackbarHelper.showError(
            context,
            ref.read(expenseProvider).error ?? 'Failed to add expense.',
          );
        }
      }
    }
  }
}

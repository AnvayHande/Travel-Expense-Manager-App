import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/models/expense_model.dart';
import '../../../../core/models/split_detail.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../presentation/providers/expense_provider.dart';
import '../../../../presentation/providers/receipt_provider.dart';
import '../../../../presentation/providers/trip_provider.dart';
import '../../../../presentation/providers/firebase_providers.dart';
import '../../../../presentation/providers/activity_provider.dart';
import '../../../../presentation/providers/authentication_provider.dart';

class ExpenseDetailsScreen extends ConsumerStatefulWidget {
  const ExpenseDetailsScreen({super.key});

  @override
  ConsumerState<ExpenseDetailsScreen> createState() =>
      _ExpenseDetailsScreenState();
}

class _ExpenseDetailsScreenState extends ConsumerState<ExpenseDetailsScreen> {
  ExpenseModel? _expense;
  bool _dataLoaded = false;
  XFile? _newReceiptImage;
  bool _isUploadingNewReceipt = false;
  String? _tripId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  void _initData() {
    if (_dataLoaded) return;
    final routeState = GoRouterState.of(context);
    _tripId = routeState.pathParameters['tripId'] ?? '';
    _expense = routeState.extra as ExpenseModel?;
    _dataLoaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    _initData();

    if (_expense == null) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Expense Details'),
        body: Center(
          child: Text('Expense not found',
              style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ),
      );
    }

    final expense = _expense!;

    final tripAsync = ref.watch(tripByIdProvider(_tripId ?? ''));
    final trip = tripAsync.valueOrNull;
    final isReadOnly = trip != null && !trip.isActive;

    return Scaffold(
      appBar: CustomAppBar(
        title: expense.expenseName,
        actions: [
          if (!isReadOnly)
            PopupMenuButton<String>(
              onSelected: (value) =>
                  _handleMenuAction(context, value, colorScheme),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outlined, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(expense, colorScheme),
            const SizedBox(height: 24),
            _buildInfoCard(expense, colorScheme),
            const SizedBox(height: 24),
            _buildParticipantsCard(expense, colorScheme),
            if (expense.receiptUrl != null ||
                _newReceiptImage != null ||
                _isUploadingNewReceipt) ...[
              const SizedBox(height: 24),
              _buildReceiptSection(expense, colorScheme, isReadOnly),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ExpenseModel expense, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.receipt_rounded, color: colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.expenseName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expense.category,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.format(expense.amount),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(ExpenseModel expense, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.person_outlined,
              label: 'Paid by',
              value: expense.paidBy,
              colorScheme: colorScheme,
              isName: true,
            ),
            const Divider(height: 24),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: DateFormatter.formatDate(expense.createdAt),
              colorScheme: colorScheme,
            ),
            if (expense.notes != null && expense.notes!.isNotEmpty) ...[
              const Divider(height: 24),
              _InfoRow(
                icon: Icons.notes_rounded,
                label: 'Notes',
                value: expense.notes!,
                colorScheme: colorScheme,
              ),
            ],
            if (expense.receiptUrl != null) ...[
              const Divider(height: 24),
              _InfoRow(
                icon: Icons.link_rounded,
                label: 'Receipt',
                value: 'Attached',
                colorScheme: colorScheme,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsCard(
      ExpenseModel expense, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people_outlined,
                    size: 20, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Split Between',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  expense.splitLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...(expense.splitDetails.isNotEmpty
                ? expense.splitDetails
                : [SplitDetail(userId: expense.paidBy)]).map((detail) =>
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ParticipantRow(
                        uid: detail.userId,
                        amount: expense.splitAmountForUser(detail.userId),
                        isPaidBy: detail.userId == expense.paidBy,
                        colorScheme: colorScheme,
                      ),
                    )),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptSection(ExpenseModel expense, ColorScheme colorScheme, bool isReadOnly) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_rounded,
                    size: 20, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Receipt',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (!isReadOnly) ...[
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Replace'),
                    onPressed: () =>
                        _showReceiptSourcePicker(context, expense),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Remove'),
                    onPressed: () => _removeReceipt(expense),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (_isUploadingNewReceipt)
              Column(
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    'Uploading receipt...',
                    style: TextStyle(
                        fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              )
            else if (_newReceiptImage != null)
              GestureDetector(
                onTap: () => _viewFullScreen(File(_newReceiptImage!.path)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_newReceiptImage!.path),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else if (expense.receiptUrl != null)
              GestureDetector(
                onTap: () => _viewFullScreen(expense.receiptUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    expense.receiptUrl!,
                    height: 200,
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
                        height: 200,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image_rounded,
                                  color: colorScheme.onSurfaceVariant),
                              const SizedBox(height: 4),
                              Text('Failed to load',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showReceiptSourcePicker(
      BuildContext context, ExpenseModel expense) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickNewReceipt(ImageSource.camera, expense);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickNewReceipt(ImageSource.gallery, expense);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickNewReceipt(ImageSource source, ExpenseModel expense) async {
    final notifier = ref.read(receiptProvider.notifier);
    final XFile? image;
    if (source == ImageSource.camera) {
      image = await notifier.pickFromCamera();
    } else {
      image = await notifier.pickFromGallery();
    }
    if (image == null) return;

    setState(() {
      _newReceiptImage = image;
      _isUploadingNewReceipt = true;
    });

    final tripId = _tripId ?? '';
    final url = await notifier.uploadReceipt(
      image: image,
      tripId: tripId,
      expenseId: expense.expenseId,
    );

    if (mounted) {
      setState(() {
        _isUploadingNewReceipt = false;
        if (url != null) {
          _newReceiptImage = null;
          _updateExpenseReceiptUrl(expense, url);
        } else {
          _newReceiptImage = null;
          SnackbarHelper.showError(context, 'Failed to upload receipt.');
        }
      });
    }
  }

  Future<void> _updateExpenseReceiptUrl(
      ExpenseModel expense, String url) async {
    final updated = expense.copyWith(receiptUrl: url);
    final success =
        await ref.read(expenseProvider.notifier).updateExpense(updated);
    if (mounted) {
      if (success) {
        setState(() => _expense = updated);
        SnackbarHelper.showSuccess(context, 'Receipt updated!');
      } else {
        SnackbarHelper.showError(context, 'Failed to save receipt URL.');
      }
    }
  }

  Future<void> _removeReceipt(ExpenseModel expense) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Remove Receipt',
      message: 'Remove the receipt image from this expense?',
      confirmLabel: 'Remove',
      icon: Icons.delete_rounded,
      confirmColor: Colors.red,
    );
    if (confirmed != true) return;

    final notifier = ref.read(receiptProvider.notifier);
    await notifier.deleteReceipt(
      tripId: _tripId ?? '',
      expenseId: expense.expenseId,
    );

    final updated = expense.copyWith(receiptUrl: null);
    final success =
        await ref.read(expenseProvider.notifier).updateExpense(updated);
    if (mounted) {
      if (success) {
        setState(() => _expense = updated);
        SnackbarHelper.showSuccess(context, 'Receipt removed.');
      } else {
        SnackbarHelper.showError(context, 'Failed to remove receipt.');
      }
    }
  }

  void _viewFullScreen(dynamic imageSource) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImagePage(imageSource: imageSource),
      ),
    );
  }

  void _handleMenuAction(
      BuildContext context, String value, ColorScheme colorScheme) {
    switch (value) {
      case 'edit':
        context.pushNamed(
          'addExpense',
          pathParameters: {'tripId': _tripId ?? ''},
          extra: _expense,
        );
      case 'delete':
        _deleteExpense(context, colorScheme);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _deleteExpense(
      BuildContext context, ColorScheme colorScheme) async {
    if (_expense == null) return;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Expense',
      message:
          'Are you sure you want to delete "${_expense!.expenseName}"?',
      confirmLabel: 'Delete',
      icon: Icons.delete_rounded,
      confirmColor: colorScheme.error,
    );
    if (confirmed == true && mounted) {
      final expenseName = _expense!.expenseName;
      final success = await ref
          .read(expenseProvider.notifier)
          .deleteExpense(_expense!.expenseId);
      if (mounted) {
        if (!context.mounted) return;
        if (success) {
          final currentUser = ref.read(authProvider).user;
          if (currentUser != null) {
            ref.read(activityServiceProvider).logActivity(
              tripId: _tripId ?? '',
              userId: currentUser.uid,
              userName: currentUser.name,
              actionType: 'expense_deleted',
              message: 'deleted "$expenseName" expense',
            );
          }
          SnackbarHelper.showSuccess(context, 'Expense deleted.');
          context.pop();
        } else {
          SnackbarHelper.showError(
            context,
            ref.read(expenseProvider).error ?? 'Failed to delete expense.',
          );
        }
      }
    }
  }
}

class _FullScreenImagePage extends StatelessWidget {
  final dynamic imageSource;

  const _FullScreenImagePage({required this.imageSource});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Receipt',
            style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          child: imageSource is String
              ? Image.network(
                  imageSource as String,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_rounded,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('Failed to load image',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : Image.file(
                  imageSource as File,
                  fit: BoxFit.contain,
                ),
        ),
      ),
    );
  }
}

class _InfoRow extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final bool isName;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorScheme,
    this.isName = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameAsync = isName ? ref.watch(userNameProvider(value)) : null;
    final display = isName ? (nameAsync?.valueOrNull ?? value) : value;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            display,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _ParticipantRow extends ConsumerWidget {
  final String uid;
  final double amount;
  final bool isPaidBy;
  final ColorScheme colorScheme;

  const _ParticipantRow({
    required this.uid,
    required this.amount,
    required this.isPaidBy,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameAsync = ref.watch(userNameProvider(uid));
    final name = nameAsync.valueOrNull ?? uid;

    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: colorScheme.surfaceContainerHighest,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        if (isPaidBy)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Paid',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
          ),
        Text(
          CurrencyFormatter.format(amount),
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface),
        ),
      ],
    );
  }
}

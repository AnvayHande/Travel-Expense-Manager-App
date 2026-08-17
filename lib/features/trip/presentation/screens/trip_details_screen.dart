import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/models/trip_model.dart';
import '../../../../core/models/expense_model.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/qr_share_dialog.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../presentation/providers/trip_provider.dart';
import '../../../../presentation/providers/authentication_provider.dart';
import '../../../../presentation/providers/expense_provider.dart';
import '../../../../presentation/providers/export_provider.dart';
import '../../../../presentation/providers/firebase_providers.dart';
import '../../../../presentation/providers/activity_provider.dart';

class TripDetailsScreen extends ConsumerWidget {
  const TripDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';
    final tripAsync = ref.watch(tripByIdProvider(tripId));
    return tripAsync.when(
      loading: () => const Scaffold(
        appBar: CustomAppBar(title: 'Trip Details'),
        body: LoadingIndicator(message: 'Loading trip...'),
      ),
      error: (err, _) => Scaffold(
        appBar: const CustomAppBar(title: 'Trip Details'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load trip',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (trip) {
        if (trip == null) {
          return Scaffold(
            appBar: const CustomAppBar(title: 'Trip Details'),
            body: Center(
              child: Text(
                'Trip not found',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
          );
        }
        return _TripDetailsContent(trip: trip);
      },
    );
  }
}

class _TripDetailsContent extends ConsumerWidget {
  final TripModel trip;

  const _TripDetailsContent({required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider).user;
    final isAdmin = user != null && trip.isAdmin(user.uid);
    final tripState = ref.watch(tripProvider);
    final exportState = ref.watch(exportProvider);
    final expensesAsync = ref.watch(tripExpensesProvider(trip.tripId));
    final unreadCount = ref.watch(unreadActivityCountProvider(trip.tripId));

    final participantNames = <String, String>{};
    for (final uid in trip.participants) {
      final nameAsync = ref.watch(userNameProvider(uid));
      participantNames[uid] = nameAsync.valueOrNull ?? uid;
    }

    ref.listen<ExportState>(exportProvider, (prev, next) {
      if (next.filePath != null &&
          prev?.filePath != next.filePath &&
          context.mounted) {
        _onExportComplete(context, next.filePath!);
        ref.read(exportProvider.notifier).clearState();
      }
      if (next.error != null &&
          prev?.error != next.error &&
          context.mounted) {
        SnackbarHelper.showError(context, next.error!);
        ref.read(exportProvider.notifier).clearState();
      }
    });

    return Scaffold(
      appBar: CustomAppBar(
        title: trip.tripName,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.pushNamed(
              'tripSettings',
              pathParameters: {'tripId': trip.tripId},
            ),
          ),
          Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(unreadCount.toString()),
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.pushNamed(
                'activity',
                pathParameters: {'tripId': trip.tripId},
              ),
            ),
          ),
          if (isAdmin)
            PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(
                context, ref, value, colorScheme,
              ),
              itemBuilder: (_) => [
                if (trip.isActive) ...[
                  const PopupMenuItem(
                    value: 'import',
                    child: Row(
                      children: [
                        Icon(Icons.upload_file, size: 20),
                        SizedBox(width: 12),
                        Text('Import Excel'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'close',
                    child: Row(
                      children: [
                        Icon(Icons.archive_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Close Trip'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                ],
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Edit Trip'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outlined, size: 20,
                          color: Colors.red),
                      SizedBox(width: 12),
                      Text('Delete Trip',
                          style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: tripState.isLoading
          ? const LoadingIndicator(message: 'Please wait...')
          : Column(
              children: [
                if (!trip.isActive)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 16,
                    ),
                    color: Colors.grey.shade700,
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline,
                            size: 16, color: Colors.grey.shade300),
                        const SizedBox(width: 8),
                        Text(
                          'This trip is completed and is now read-only.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(colorScheme),
                  const SizedBox(height: 24),
                  _buildInfoSection(colorScheme),
                  const SizedBox(height: 24),
                  _buildInviteCodeSection(context, colorScheme),
                  const SizedBox(height: 24),
                  _buildActions(
                    context, ref, colorScheme, isAdmin, expensesAsync.valueOrNull ?? [],
                    exportState.isLoading, participantNames,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trip.currency,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: trip.isActive
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trip.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: trip.isActive
                        ? Colors.green.shade100
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            trip.tripName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimary,
            ),
          ),
          if (trip.destination != null && trip.destination!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: colorScheme.onPrimary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  trip.destination!,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onPrimary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
          if (trip.description != null && trip.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              trip.description!,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onPrimary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInfoTile(
              colorScheme,
              Icons.person_outlined,
              'Admin',
              trip.adminName,
            ),
            const Divider(height: 24),
            _buildInfoTile(
              colorScheme,
              Icons.people_outlined,
              'Participants',
              '${trip.participants.length} member${trip.participants.length == 1 ? '' : 's'}',
            ),
            const Divider(height: 24),
            _buildInfoTile(
              colorScheme,
              Icons.calendar_today_outlined,
              'Start Date',
              trip.startDate != null
                  ? DateFormatter.formatDate(trip.startDate!)
                  : 'Not set',
            ),
            const Divider(height: 24),
            _buildInfoTile(
              colorScheme,
              Icons.calendar_today_outlined,
              'End Date',
              trip.endDate != null
                  ? DateFormatter.formatDate(trip.endDate!)
                  : 'Not set',
            ),
            const Divider(height: 24),
            _buildInfoTile(
              colorScheme,
              Icons.attach_money_rounded,
              'Currency',
              trip.currency,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCodeSection(BuildContext context, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.vpn_key_rounded,
                color: colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite Code',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trip.inviteCode ?? 'N/A',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                SnackbarHelper.showInfo(context, 'Invite code copied!');
              },
              icon: const Icon(Icons.copy_rounded),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    ColorScheme colorScheme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    bool isAdmin,
    List<ExpenseModel> expenses,
    bool isExporting,
    Map<String, String> participantNames,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'Participants',
                icon: Icons.people_outlined,
                onPressed: () => context.pushNamed(
                  'participants',
                  pathParameters: {'tripId': trip.tripId},
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: 'Expenses',
                icon: Icons.receipt_outlined,
                onPressed: () => context.pushNamed(
                  'expenses',
                  pathParameters: {'tripId': trip.tripId},
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Settlement',
                icon: Icons.balance_rounded,
                onPressed: () => context.pushNamed(
                  'settlement',
                  pathParameters: {'tripId': trip.tripId},
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SecondaryButton(
                label: 'Dashboard',
                icon: Icons.dashboard_rounded,
                onPressed: () => context.pushNamed(
                  'dashboard',
                  pathParameters: {'tripId': trip.tripId},
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Share QR',
                icon: Icons.qr_code_rounded,
                onPressed: () => QRShareDialog.show(
                  context,
                  tripName: trip.tripName,
                  inviteCode: trip.inviteCode ?? '',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SecondaryButton(
                label: 'Activity',
                icon: Icons.history_rounded,
                onPressed: () => context.pushNamed(
                  'activity',
                  pathParameters: {'tripId': trip.tripId},
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Budget',
                  icon: Icons.account_balance_wallet_rounded,
                  onPressed: () => context.pushNamed(
                    'budgetDashboard',
                    pathParameters: {'tripId': trip.tripId},
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SecondaryButton(
                  label: 'Categories',
                  icon: Icons.category_rounded,
                  onPressed: () => context.pushNamed(
                    'categoryManagement',
                    pathParameters: {'tripId': trip.tripId},
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Insights',
                  icon: Icons.insights_rounded,
                  onPressed: () => context.pushNamed(
                    'insights',
                    pathParameters: {'tripId': trip.tripId},
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SecondaryButton(
                  label: 'Templates',
                  icon: Icons.description_outlined,
                  onPressed: () => context.pushNamed(
                    'templateManagement',
                    pathParameters: {'tripId': trip.tripId},
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SecondaryButton(
              label: 'Export Excel',
              icon: Icons.file_download_outlined,
              isLoading: isExporting,
              onPressed: expenses.isEmpty
                  ? null
                  : () => _exportTrip(
                      context, ref, expenses, participantNames),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Generate Report',
              icon: Icons.picture_as_pdf_rounded,
              onPressed: () => context.pushNamed(
                'report',
                pathParameters: {'tripId': trip.tripId},
              ),
            ),
          ),
        ],
      );
    }

  Future<void> _exportTrip(
    BuildContext context,
    WidgetRef ref,
    List<ExpenseModel> expenses,
    Map<String, String> participantNames,
  ) async {
    await ref.read(exportProvider.notifier).exportTrip(
      tripId: trip.tripId,
      tripName: trip.tripName,
      expenses: expenses,
      participants: trip.participants,
      participantNames: participantNames,
      date: DateTime.now(),
    );
  }

  Future<void> _onExportComplete(
      BuildContext context, String filePath) async {
    SnackbarHelper.showSuccess(context, 'Excel exported successfully!');
    await Share.shareXFiles(
      [XFile(filePath)],
      text: '${trip.tripName} - Trip Expenses',
    );
  }

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String value,
    ColorScheme colorScheme,
  ) {
    switch (value) {
      case 'import':
        context.pushNamed(
          'import',
          pathParameters: {'tripId': trip.tripId},
        );
      case 'close':
        context.pushNamed(
          'closeTrip',
          pathParameters: {'tripId': trip.tripId},
        );
      case 'edit':
        if (trip.isActive) {
          _showEditDialog(context, ref, colorScheme);
        }
      case 'delete':
        _showDeleteConfirmation(context, ref, colorScheme);
    }
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
  ) {
    final nameCtrl = TextEditingController(text: trip.tripName);
    final destCtrl = TextEditingController(text: trip.destination ?? '');
    final descCtrl = TextEditingController(text: trip.description ?? '');
    String currency = trip.currency;
    DateTime? startDate = trip.startDate;
    DateTime? endDate = trip.endDate;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Trip',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Trip Name *'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: destCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Destination'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: currency,
                    decoration:
                        const InputDecoration(labelText: 'Currency'),
                    items: const [
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                      DropdownMenuItem(value: 'INR', child: Text('INR')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                      DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setSheetState(() => currency = v);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final updated = trip.copyWith(
                              tripName: nameCtrl.text.trim(),
                              destination: destCtrl.text.trim().isEmpty
                                  ? null
                                  : destCtrl.text.trim(),
                              description: descCtrl.text.trim().isEmpty
                                  ? null
                                  : descCtrl.text.trim(),
                              currency: currency,
                              startDate: startDate,
                              endDate: endDate,
                            );
                            final success = await ref
                                .read(tripProvider.notifier)
                                .updateTrip(updated);
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                              if (success) {
                if (context.mounted) {
                  SnackbarHelper.showSuccess(
                    context,
                    'Trip updated successfully!',
                  );
                }
                              }
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
  ) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Trip',
      message:
          'Are you sure you want to delete "${trip.tripName}"? This will permanently remove all expenses, settlements, and activity history.',
      confirmLabel: 'Delete Everything',
      icon: Icons.delete_rounded,
      confirmColor: colorScheme.error,
    );
    if (confirmed == true && context.mounted) {
      final success = await ref
          .read(tripProvider.notifier)
          .deleteTripWithAllData(trip.tripId);
      if (context.mounted) {
        if (success) {
          SnackbarHelper.showSuccess(context, 'Trip deleted.');
          context.goNamed('home');
        } else {
          SnackbarHelper.showError(
            context,
            ref.read(tripProvider).error ?? 'Failed to delete trip.',
          );
        }
      }
    }
  }
}

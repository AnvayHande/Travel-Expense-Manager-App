import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/models/trip_model.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../presentation/providers/report_provider.dart';
import '../../../../presentation/providers/expense_provider.dart';
import '../../../../presentation/providers/trip_provider.dart';
import '../../../../presentation/providers/settlement_provider.dart';
import '../../../../presentation/providers/category_provider.dart';
import '../../../../presentation/providers/firebase_providers.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  bool _hasGenerated = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';
    final tripAsync = ref.watch(tripByIdProvider(tripId));
    final reportState = ref.watch(reportProvider);

    ref.listen<ReportState>(reportProvider, (prev, next) {
      if (next.filePath != null && prev?.filePath != next.filePath && mounted) {
        SnackbarHelper.showSuccess(context, 'Report generated successfully!');
      }
      if (next.error != null && prev?.error != next.error && mounted) {
        SnackbarHelper.showError(context, next.error!);
        ref.read(reportProvider.notifier).clearState();
      }
    });

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Trip Report',
        actions: reportState.filePath != null
            ? [
                IconButton(
                  icon: const Icon(Icons.share_rounded),
                  onPressed: () => _shareReport(reportState.filePath!),
                  tooltip: 'Share PDF',
                ),
              ]
            : null,
      ),
      body: tripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (trip) {
          if (trip == null) {
            return Center(
              child: Text('Trip not found',
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
            );
          }
          return _buildContent(trip, tripId, colorScheme, reportState);
        },
      ),
    );
  }

  Widget _buildContent(
    TripModel trip,
    String tripId,
    ColorScheme colorScheme,
    ReportState reportState,
  ) {
    if (reportState.isLoading) {
      return _buildLoadingState(colorScheme, reportState.progress);
    }

    if (reportState.filePath != null) {
      return _buildSuccessState(
        context, colorScheme, reportState.filePath!, trip.tripName);
    }

    if (!_hasGenerated) {
      return _buildInitialState(trip, tripId, colorScheme);
    }

    return _buildInitialState(trip, tripId, colorScheme);
  }

  Widget _buildInitialState(
    TripModel trip,
    String tripId,
    ColorScheme colorScheme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
                Icon(Icons.description_rounded,
                    size: 48, color: colorScheme.onPrimary),
                const SizedBox(height: 16),
                Text(
                  'Trip Report Generator',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Generate a professional multi-page PDF report for ${trip.tripName}.',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onPrimary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Report Contents',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      )),
                  const SizedBox(height: 16),
                  _pageItem(Icons.description_rounded, 'Page 1',
                      'Cover & Trip Overview', colorScheme),
                  _pageItem(Icons.table_chart_rounded, 'Page 2',
                      'Expense Summary Table', colorScheme),
                  _pageItem(Icons.people_rounded, 'Page 3',
                      'Participant Summary', colorScheme),
                  _pageItem(Icons.analytics_rounded, 'Page 4',
                      'Analytics & Charts', colorScheme),
                  _pageItem(Icons.account_balance_rounded, 'Page 5',
                      'Settlement Summary', colorScheme),
                  _pageItem(Icons.photo_library_rounded, 'Page 6',
                      'Trip Memories', colorScheme),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Generate Report',
              icon: Icons.picture_as_pdf_rounded,
              onPressed: () => _generateReport(trip, tripId),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageItem(IconData icon, String page, String description, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(page,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  )),
              Text(description,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme, double progress) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 6,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Generating your report...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a moment.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState(
    BuildContext context,
    ColorScheme colorScheme,
    String filePath,
    String tripName,
  ) {
    final fileName = filePath.split('\\').last.split('/').last;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 48, color: Colors.green),
            ),
            const SizedBox(height: 24),
            Text(
              'Report Generated!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.picture_as_pdf_rounded,
                      size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Share PDF',
                    icon: Icons.share_rounded,
                    onPressed: () => _shareReport(filePath),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Save Locally',
                    icon: Icons.download_rounded,
                    onPressed: () => _saveLocally(filePath),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                label: 'Generate Again',
                icon: Icons.refresh_rounded,
                onPressed: () {
                  ref.read(reportProvider.notifier).clearState();
                  setState(() => _hasGenerated = false);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateReport(TripModel trip, String tripId) async {
    setState(() => _hasGenerated = true);

    final expensesAsync = ref.read(tripExpensesProvider(tripId));
    final expenses = expensesAsync.valueOrNull ?? [];
    final balances = ref.read(tripBalanceProvider(tripId)) ?? {};
    final pendingTransactions = ref.read(tripPendingTransactionsProvider(tripId));
    final settlementsAsync = ref.read(tripCompletedSettlementsProvider(tripId));
    final catInfo = ref.read(categoryInfoProvider(tripId));

    final participantNames = <String, String>{};
    for (final uid in trip.participants) {
      final nameAsync = ref.read(userNameProvider(uid));
      participantNames[uid] = nameAsync.valueOrNull ?? uid;
    }

    await ref.read(reportProvider.notifier).generateReport(
      trip: trip,
      expenses: expenses,
      participantNames: participantNames,
      balances: balances,
      pendingTransactions: pendingTransactions,
      completedSettlements: settlementsAsync,
      catInfo: catInfo,
      totalBudget: trip.totalBudget,
    );
  }

  Future<void> _shareReport(String filePath) async {
    if (kIsWeb || filePath == 'web-downloaded') {
      SnackbarHelper.showInfo(context, 'Report has been downloaded.');
      return;
    }
    final file = XFile(filePath);
    await Share.shareXFiles([file], text: 'Trip Report');
  }

  Future<void> _saveLocally(String filePath) async {
    if (kIsWeb || filePath == 'web-downloaded') {
      SnackbarHelper.showSuccess(context, 'Report has been downloaded to your device.');
      return;
    }
    SnackbarHelper.showSuccess(context, 'Report saved to: $filePath');
  }
}

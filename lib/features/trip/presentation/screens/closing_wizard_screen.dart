import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import '../../../../core/models/expense_model.dart';
import '../../../../core/models/trip_model.dart';
import '../../../../core/models/category_model.dart';
import '../../../../core/services/expense_filter_service.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/budget_service.dart';
import '../../../../core/services/report_service.dart';
import '../../../../core/services/settlement_service.dart';
import '../../../../core/utils/file_helper.dart';
import '../../../../core/repositories/expense_repository.dart';
import '../../../../core/repositories/settlement_repository.dart';
import '../../../../presentation/providers/closing_wizard_provider.dart';
import '../../../../presentation/providers/authentication_provider.dart';
import '../../../../presentation/providers/trip_provider.dart';
import '../../../../presentation/providers/category_provider.dart';

class ClosingWizardScreen extends ConsumerStatefulWidget {
  const ClosingWizardScreen({super.key});

  @override
  ConsumerState<ClosingWizardScreen> createState() => _ClosingWizardScreenState();
}

class _ClosingWizardScreenState extends ConsumerState<ClosingWizardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(closingWizardProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';
    final tripAsync = ref.watch(tripByIdProvider(tripId));
    final wizardState = ref.watch(closingWizardProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Close Trip'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _handleBack(context, wizardState),
        ),
      ),
      body: tripAsync.when(
        data: (trip) {
          if (trip == null) {
            return const Center(child: Text('Trip not found'));
          }
          return _buildContent(context, trip, wizardState, theme);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _handleBack(BuildContext context, ClosingWizardState state) {
    if (state.archiveComplete) {
      context.go('/home');
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Close trip wizard'),
          content: const Text('Are you sure you want to cancel closing this trip?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Continue Wizard')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/home');
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildContent(
    BuildContext context,
    TripModel trip,
    ClosingWizardState state,
    ThemeData theme,
  ) {
    return Column(
      children: [
        _buildStepper(state.currentStep, theme),
        const Divider(height: 1),
        Expanded(
          child: _buildStepContent(context, trip, state, theme),
        ),
      ],
    );
  }

  Widget _buildStepper(WizardStep step, ThemeData theme) {
    final steps = [
      ('Expenses', Icons.receipt_long),
      ('Settlements', Icons.handshake),
      ('Reports', Icons.description),
      ('Archive', Icons.archive),
    ];

    final stepIndex = WizardStep.values.indexOf(step);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i <= stepIndex;
          final isCurrent = i == stepIndex;
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isActive ? theme.colorScheme.primary : theme.colorScheme.outline.withAlpha(80),
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        steps[i].$2,
                        size: 16,
                        color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[i].$1,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(
    BuildContext context,
    TripModel trip,
    ClosingWizardState state,
    ThemeData theme,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.read(closingWizardProvider.notifier).reset(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    switch (state.currentStep) {
      case WizardStep.expenseCheck:
        return _ExpenseCheckStep(trip: trip, state: state);
      case WizardStep.settlementCheck:
        return _SettlementCheckStep(trip: trip, state: state);
      case WizardStep.generateReports:
        return _GenerateReportsStep(trip: trip, state: state);
      case WizardStep.archive:
        return _ArchiveStep(trip: trip, state: state);
    }
  }
}

class _ExpenseCheckStep extends ConsumerWidget {
  final TripModel trip;
  final ClosingWizardState state;

  const _ExpenseCheckStep({required this.trip, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            state.expenseCheckPassed ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 64,
            color: state.expenseCheckPassed ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 16),
          Text(
            state.expenseCheckPassed ? 'Expenses Found' : 'No Expenses Recorded',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            state.expenseCheckPassed
                ? 'Your trip has ${state.expenseCount} expense${state.expenseCount == 1 ? '' : 's'} totaling \$${state.expenseTotal.toStringAsFixed(2)}.'
                : 'This trip has no expenses. You can add expenses before closing, or close anyway.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    ref.read(closingWizardProvider.notifier).checkExpenses(trip.tripId);
                  },
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettlementCheckStep extends ConsumerWidget {
  final TripModel trip;
  final ClosingWizardState state;

  const _SettlementCheckStep({required this.trip, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            state.settlementCheckPassed ? Icons.check_circle : Icons.account_balance_wallet,
            size: 64,
            color: state.settlementCheckPassed ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 16),
          Text(
            state.settlementCheckPassed ? 'All Settled!' : 'Pending Settlements',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (state.settlementCheckPassed)
            Text(
              'Everyone has settled up. No outstanding balances.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else
            Column(
              children: [
                Text(
                  '${state.pendingSettlementCount} settlement${state.pendingSettlementCount == 1 ? '' : 's'} pending.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can close anyway or settle up first.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (!state.settlementCheckPassed) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/trip/${trip.tripId}/settlement'),
                    icon: const Icon(Icons.handshake, size: 18),
                    label: const Text('Settle Up'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (state.settlementCheckPassed) {
                      ref.read(closingWizardProvider.notifier).checkSettlements(
                        trip.tripId, [], trip,
                      );
                    } else {
                      ref.read(closingWizardProvider.notifier).skipToGenerateReports();
                    }
                  },
                  child: Text(state.settlementCheckPassed ? 'Continue' : 'Close Anyway'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenerateReportsStep extends ConsumerStatefulWidget {
  final TripModel trip;
  final ClosingWizardState state;

  const _GenerateReportsStep({required this.trip, required this.state});

  @override
  ConsumerState<_GenerateReportsStep> createState() => _GenerateReportsStepState();
}

class _GenerateReportsStepState extends ConsumerState<_GenerateReportsStep> {
  bool _generating = false;
  String? _pdfPath;
  String? _excelPath;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            _pdfPath != null ? Icons.check_circle : Icons.description,
            size: 64,
            color: _pdfPath != null ? Colors.green : theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            _pdfPath != null ? 'Reports Generated' : 'Generate Reports',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (_generating)
            const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating reports...'),
              ],
            )
          else if (_error != null)
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            )
          else if (_pdfPath == null)
            Text(
              'Generate PDF report and Excel export before archiving.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else
            Text(
              'Reports are ready for download.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          if (!_generating && _pdfPath != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _sharePdf,
              icon: const Icon(Icons.share),
              label: const Text('Share PDF Report'),
            ),
            if (_excelPath != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _shareExcel,
                icon: const Icon(Icons.share),
                label: const Text('Share Excel Export'),
              ),
            ],
          ],
          const Spacer(),
          if (_pdfPath == null && !_generating)
            FilledButton.icon(
              onPressed: _generateReports,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Reports'),
            ),
          if (_pdfPath != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(closingWizardProvider.notifier).skipToGenerateReports();
                    },
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      _archiveTrip(context);
                    },
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generateReports() async {
    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      final expenses = await ref.read(expenseRepositoryProvider).getTripExpenses(widget.trip.tripId).first;
      final catSnapshot = ref.read(categoryRepositoryProvider).getTripCategories(widget.trip.tripId);
      final catList = await catSnapshot.first;
      final catInfo = <String, CategoryModel>{};
      for (final cat in catList) {
        catInfo[cat.name] = cat;
      }

      final settlementsAsync = ref.read(settlementRepositoryProvider).getTripSettlements(widget.trip.tripId);
      final settlements = await settlementsAsync.first;
      final completedSettlements = settlements.where((s) => s.isSettled).toList();

      final settlementService = SettlementService();

      final paid = <String, double>{};
      final owed = <String, double>{};

      for (final uid in widget.trip.participants) {
        paid[uid] = 0.0;
        owed[uid] = 0.0;
      }

      for (final expense in expenses) {
        paid[expense.paidBy] = (paid[expense.paidBy] ?? 0.0) + expense.amount;
        for (final detail in expense.splitDetails) {
          owed[detail.userId] =
              (owed[detail.userId] ?? 0.0) + expense.splitAmountForUser(detail.userId);
        }
      }

      final balances = <String, BalanceInfo>{};
      for (final uid in widget.trip.participants) {
        final tp = paid[uid] ?? 0.0;
        final to = owed[uid] ?? 0.0;
        balances[uid] = BalanceInfo(
          userId: uid,
          totalPaid: tp,
          totalOwed: to,
          netBalance: tp - to,
        );
      }

      final participantBalances = balances.values
          .map((b) => ParticipantBalance(userId: b.userId, netBalance: b.netBalance))
          .toList();
      final allTransactions = settlementService.calculateMinimumTransactions(participantBalances);
      final completedPairs = completedSettlements
          .map((s) => '${s.fromUser}-${s.toUser}')
          .toSet();
      final pendingTransactions = allTransactions
          .where((t) => !completedPairs.contains('${t.fromUserId}-${t.toUserId}'))
          .toList();

      final participantNames = <String, String>{};
      for (final uid in widget.trip.participants) {
        participantNames[uid] = uid;
      }

      final filterService = ExpenseFilterService();
      final analyticsService = AnalyticsService(filterService: filterService);

      final reportService = ReportService(
        filterService: filterService,
        analyticsService: analyticsService,
      );

      final budgetService = BudgetService();
      final budgetData = budgetService.calculate(
        categories: catInfo.values.toList(),
        expenses: expenses,
        totalBudget: widget.trip.totalBudget,
      );

      final bytes = await reportService.generateReport(
        trip: widget.trip,
        expenses: expenses,
        participantNames: participantNames,
        balances: balances,
        pendingTransactions: pendingTransactions,
        completedSettlements: completedSettlements,
        budgetData: budgetData,
        catInfo: catInfo,
      );

      final dateStr = '${DateTime.now().year}-'
          '${DateTime.now().month.toString().padLeft(2, '0')}-'
          '${DateTime.now().day.toString().padLeft(2, '0')}';
      final safeName = widget.trip.tripName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');

      final pdfPath = await FileHelper.saveFile('${safeName}_Report_$dateStr.pdf', bytes, mimeType: 'application/pdf');

      final excelPath = await _generateExcel(expenses, safeName, dateStr);

      setState(() {
        _pdfPath = pdfPath;
        _excelPath = excelPath;
        _generating = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _generating = false;
      });
    }
  }

  Future<String?> _generateExcel(
    List<ExpenseModel> expenses,
    String safeName,
    String dateStr,
  ) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Expenses'];
      final sorted = List<ExpenseModel>.from(expenses)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      _setCell(sheet, 0, 0, 'Expense Name');
      _setCell(sheet, 1, 0, 'Category');
      _setCell(sheet, 2, 0, 'Paid By');
      _setCell(sheet, 3, 0, 'Amount');
      _setCell(sheet, 4, 0, 'Split Type');
      _setCell(sheet, 5, 0, 'Date');

      for (var i = 0; i < sorted.length; i++) {
        final e = sorted[i];
        final row = i + 1;
        _setCell(sheet, 0, row, e.expenseName);
        _setCell(sheet, 1, row, e.category);
        _setCell(sheet, 2, row, e.paidBy);
        _setCell(sheet, 3, row, e.amount);
        _setCell(sheet, 4, row, e.splitLabel);
        _setCell(sheet, 5, row, '${e.createdAt.day}/${e.createdAt.month}/${e.createdAt.year}');
      }

      final fileName = '${safeName}_Export_$dateStr.xlsx';
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel');
      
      return await FileHelper.saveFile(
        fileName, 
        Uint8List.fromList(bytes),
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } catch (_) {
      return null;
    }
  }

  void _setCell(Sheet sheet, int col, int row, dynamic value) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    if (value is num) {
      cell.value = DoubleCellValue(value.toDouble());
    } else {
      cell.value = TextCellValue(value?.toString() ?? '');
    }
  }

  void _sharePdf() {
    if (_pdfPath != null) {
      if (kIsWeb || _pdfPath == 'web-downloaded') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report has been downloaded.')));
        return;
      }
      Share.shareXFiles([XFile(_pdfPath!)], text: '${widget.trip.tripName} - Report');
    }
  }

  void _shareExcel() {
    if (_excelPath != null) {
      if (kIsWeb || _excelPath == 'web-downloaded') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel file has been downloaded.')));
        return;
      }
      Share.shareXFiles([XFile(_excelPath!)], text: '${widget.trip.tripName} - Export');
    }
  }

  void _archiveTrip(BuildContext context) {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    ref.read(closingWizardProvider.notifier).archiveTrip(
      tripId: widget.trip.tripId,
      tripName: widget.trip.tripName,
      adminId: user.uid,
      adminName: user.name.isNotEmpty ? user.name : user.email,
    );
  }
}

class _ArchiveStep extends ConsumerWidget {
  final TripModel trip;
  final ClosingWizardState state;

  const _ArchiveStep({required this.trip, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            state.archiveComplete ? Icons.check_circle : Icons.archive,
            size: 80,
            color: state.archiveComplete ? Colors.green : theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            state.archiveComplete ? 'Trip Closed!' : 'Archiving...',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (state.archiveComplete)
            Text(
              '"${trip.tripName}" has been closed and moved to Past Trips.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          const Spacer(),
          if (state.archiveComplete)
            FilledButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.home),
              label: const Text('Back to Home'),
            ),
        ],
      ),
    );
  }
}

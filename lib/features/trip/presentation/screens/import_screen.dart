import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/models/trip_model.dart';
import '../../../../core/services/import_service.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../presentation/providers/import_provider.dart';
import '../../../../presentation/providers/trip_provider.dart';
import '../../../../presentation/providers/firebase_providers.dart';
import '../../../../presentation/providers/authentication_provider.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  String? _selectedFilePath;
  bool _selectAll = true;
  final Set<String> _selectedExpenses = {};

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';
    final tripAsync = ref.watch(tripByIdProvider(tripId));
    final importState = ref.watch(importProvider);

    return tripAsync.when(
      loading: () => const Scaffold(
        appBar: CustomAppBar(title: 'Import Expenses'),
        body: LoadingIndicator(message: 'Loading trip...'),
      ),
      error: (err, _) => Scaffold(
        appBar: const CustomAppBar(title: 'Import Expenses'),
        body: Center(child: Text('Error: $err')),
      ),
      data: (trip) {
        if (trip == null) {
          return const Scaffold(
            appBar: CustomAppBar(title: 'Import Expenses'),
            body: Center(child: Text('Trip not found')),
          );
        }

        return Scaffold(
          appBar: CustomAppBar(
            title: 'Import Expenses',
            actions: [
              if (importState.status != ImportStatus.idle)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    ref.read(importProvider.notifier).reset();
                    setState(() {
                      _selectedFilePath = null;
                      _selectAll = true;
                      _selectedExpenses.clear();
                    });
                  },
                ),
            ],
          ),
          body: _buildBody(colorScheme, textTheme, trip, importState),
        );
      },
    );
  }

  Widget _buildBody(
    ColorScheme colorScheme,
    TextTheme textTheme,
    TripModel trip,
    ImportProviderState importState,
  ) {
    switch (importState.status) {
      case ImportStatus.idle:
        return _buildIdleState(colorScheme, textTheme, trip);
      case ImportStatus.parsing:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Parsing Excel file...'),
            ],
          ),
        );
      case ImportStatus.preview:
        return _buildPreviewState(colorScheme, textTheme, importState, trip);
      case ImportStatus.importing:
        return _buildImportingState(colorScheme, textTheme, importState);
      case ImportStatus.summary:
        return _buildSummaryState(colorScheme, textTheme, importState, trip);
      case ImportStatus.error:
        return _buildErrorState(colorScheme, textTheme, importState);
    }
  }

  Widget _buildIdleState(
    ColorScheme colorScheme,
    TextTheme textTheme,
    TripModel trip,
  ) {
    final isAdmin = trip.adminId == ref.read(authProvider).user?.uid;

    if (!isAdmin) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, size: 64, color: colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'Only the trip admin can import expenses.',
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (trip.status == 'completed') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.archive, size: 64, color: colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'Cannot import expenses to a completed trip.',
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload_file, size: 64, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Import Expenses from Excel',
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Select an Excel file (.xlsx) with expense data.\n'
              'Required columns: Expense Name, Amount, Paid By\n'
              'Optional: Category, Split Type, Participants, Date, Notes',
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_selectedFilePath != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _selectedFilePath!.split('\\').last,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _selectedFilePath = null),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            PrimaryButton(
              label: _selectedFilePath == null ? 'Select Excel File' : 'Parse File',
              icon: _selectedFilePath == null ? Icons.folder_open : Icons.play_arrow,
              onPressed: _pickAndParseFile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewState(
    ColorScheme colorScheme,
    TextTheme textTheme,
    ImportProviderState importState,
    TripModel trip,
  ) {
    final preview = importState.preview!;
    final validRows = preview.rows.where((r) => r.isValid && !r.isDuplicate).toList();
    final invalidRows = preview.rows.where((r) => !r.isValid).toList();
    final duplicateRows = preview.rows.where((r) => r.isDuplicate).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              _StatChip(
                label: 'Total',
                value: '${preview.totalRows}',
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Valid',
                value: '${preview.validRows}',
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Invalid',
                value: '${preview.invalidRows}',
                color: Colors.red,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Duplicates',
                value: '${preview.duplicateCount}',
                color: Colors.orange,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              if (validRows.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _selectAll,
                        onChanged: (v) {
                          setState(() {
                            _selectAll = v ?? false;
                            if (_selectAll) {
                              _selectedExpenses.addAll(validRows.map((r) => r.expenseName ?? ''));
                            } else {
                              _selectedExpenses.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      Text('Select All', style: textTheme.labelLarge),
                      const Spacer(),
                      Text('${_selectedExpenses.length} selected',
                          style: textTheme.bodySmall),
                    ],
                  ),
                ),
                ...validRows.map((row) => _buildRowTile(row, colorScheme, textTheme)),
              ],
              if (invalidRows.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Invalid Rows (${invalidRows.length})',
                    style: textTheme.titleSmall?.copyWith(color: Colors.red),
                  ),
                ),
                ...invalidRows.map((row) => _buildRowTile(row, colorScheme, textTheme)),
              ],
              if (duplicateRows.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Duplicates (${duplicateRows.length})',
                    style: textTheme.titleSmall?.copyWith(color: Colors.orange),
                  ),
                ),
                ...duplicateRows.map((row) => _buildRowTile(row, colorScheme, textTheme)),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
        if (validRows.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Import All',
                      icon: Icons.download,
                      onPressed: () => _importAll(trip),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Import Selected',
                      icon: Icons.download_done,
                      onPressed: _selectedExpenses.isNotEmpty
                          ? () => _importSelected(trip)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRowTile(ImportRow row, ColorScheme colorScheme, TextTheme textTheme) {
    final isSelected = _selectedExpenses.contains(row.expenseName);

    return Opacity(
      opacity: row.isValid && !row.isDuplicate ? 1.0 : 0.5,
      child: ListTile(
        leading: row.isValid && !row.isDuplicate
            ? Checkbox(
                value: isSelected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedExpenses.add(row.expenseName ?? '');
                    } else {
                      _selectedExpenses.remove(row.expenseName ?? '');
                    }
                  });
                },
              )
            : Icon(
                row.isDuplicate ? Icons.copy : Icons.warning_amber,
                color: row.isDuplicate ? Colors.orange : Colors.red,
              ),
        title: Text(
          row.expenseName ?? 'Unknown',
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          [
            if (row.amount != null) '\$${row.amount!.toStringAsFixed(2)}',
            if (row.paidByName != null) row.paidByName,
            if (row.category != null) row.category,
            if (row.validationError != null) '[${row.validationError}]',
            if (row.isDuplicate) '[Duplicate]',
          ].join(' · '),
          style: textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        dense: true,
      ),
    );
  }

  Widget _buildImportingState(
    ColorScheme colorScheme,
    TextTheme textTheme,
    ImportProviderState importState,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: importState.progress > 0 ? importState.progress : null),
            const SizedBox(height: 16),
            Text(
              'Importing expenses...',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${(importState.progress * 100).toStringAsFixed(0)}%',
              style: textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryState(
    ColorScheme colorScheme,
    TextTheme textTheme,
    ImportProviderState importState,
    TripModel trip,
  ) {
    final summary = importState.summary!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              summary.imported > 0 ? Icons.check_circle : Icons.info,
              size: 64,
              color: summary.imported > 0 ? Colors.green : colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Import Complete',
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            _SummaryRow(label: 'Imported', value: '${summary.imported}', color: Colors.green),
            _SummaryRow(label: 'Failed', value: '${summary.failed}', color: Colors.red),
            _SummaryRow(label: 'Duplicates Skipped', value: '${summary.duplicates}', color: Colors.orange),
            _SummaryRow(label: 'Invalid Skipped', value: '${summary.skipped}', color: Colors.orange),
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'Done',
              icon: Icons.check,
              onPressed: () {
                ref.read(importProvider.notifier).reset();
                context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    ColorScheme colorScheme,
    TextTheme textTheme,
    ImportProviderState importState,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Import Error',
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              importState.error ?? 'Unknown error',
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Try Again',
              icon: Icons.refresh,
              onPressed: () {
                ref.read(importProvider.notifier).reset();
                setState(() {
                  _selectedFilePath = null;
                  _selectAll = true;
                  _selectedExpenses.clear();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndParseFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    if (!mounted) return;

    setState(() => _selectedFilePath = filePath);

    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';

    ref.read(importProvider.notifier).parseFile(
      filePath: filePath,
      tripId: tripId,
    );
  }

  Future<void> _importAll(TripModel trip) async {
    final nameMap = await _buildParticipantNameMap(trip);
    ref.read(importProvider.notifier).importAll(
      tripId: trip.tripId,
      participantNameToId: nameMap,
    );
  }

  Future<void> _importSelected(TripModel trip) async {
    final nameMap = await _buildParticipantNameMap(trip);
    ref.read(importProvider.notifier).importSelected(
      expenseNames: _selectedExpenses.toList(),
      tripId: trip.tripId,
      participantNameToId: nameMap,
    );
  }

  Future<Map<String, String>> _buildParticipantNameMap(TripModel trip) async {
    final nameMap = <String, String>{};
    for (final uid in trip.participants) {
      final name = await ref.read(userNameProvider(uid).future);
      nameMap[name] = uid;
    }
    return nameMap;
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text('$label: ', style: Theme.of(context).textTheme.bodyLarge),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

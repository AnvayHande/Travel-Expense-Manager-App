import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/services/insights_service.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../presentation/providers/insights_provider.dart';
import '../../../../presentation/providers/category_provider.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  final _repaintKey = GlobalKey();
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';
    final insights = ref.watch(tripInsightsProvider(tripId));

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Trip Insights',
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleExport(context, value, tripId),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'png',
                child: Row(
                  children: [
                    Icon(Icons.image_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Export as PNG'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Export as PDF'),
                  ],
                ),
              ),
            ],
            child: _isExporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: RepaintBoundary(
        key: _repaintKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Overview', Icons.dashboard_rounded, colorScheme),
              const SizedBox(height: 12),
              _buildOverviewGrid(insights, colorScheme),
              const SizedBox(height: 24),
              _buildSectionTitle('Category Insights', Icons.category_rounded, colorScheme),
              const SizedBox(height: 12),
              _buildCategoryInsights(insights, tripId, colorScheme),
              const SizedBox(height: 24),
              _buildSectionTitle('Participant Insights', Icons.people_rounded, colorScheme),
              const SizedBox(height: 12),
              _buildParticipantInsights(insights, colorScheme),
              const SizedBox(height: 24),
              _buildSectionTitle('Expense Insights', Icons.receipt_long_rounded, colorScheme),
              const SizedBox(height: 12),
              _buildExpenseInsights(insights, colorScheme),
              const SizedBox(height: 24),
              _buildSectionTitle('Spending Timeline', Icons.timeline_rounded, colorScheme),
              const SizedBox(height: 12),
              _buildTimeline(insights, colorScheme),
              const SizedBox(height: 24),
              _buildSectionTitle('Smart Insights', Icons.lightbulb_outlined, colorScheme),
              const SizedBox(height: 12),
              _buildSmartInsights(insights, colorScheme),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewGrid(TripInsights insights, ColorScheme colorScheme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatCard(
              icon: Icons.attach_money_rounded,
              label: 'Total Trip Cost',
              value: CurrencyFormatter.format(insights.totalTripCost),
              color: colorScheme.primary,
              colorScheme: colorScheme,
            )),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(
              icon: Icons.people_outlined,
              label: 'Participants',
              value: '${insights.totalParticipants}',
              color: colorScheme.tertiary,
              colorScheme: colorScheme,
            )),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatCard(
              icon: Icons.receipt_outlined,
              label: 'Total Expenses',
              value: '${insights.totalExpenses}',
              color: Colors.teal,
              colorScheme: colorScheme,
            )),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(
              icon: Icons.calculate_rounded,
              label: 'Average Expense',
              value: CurrencyFormatter.format(insights.averageExpense),
              color: Colors.indigo,
              colorScheme: colorScheme,
            )),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatCard(
              icon: Icons.person_rounded,
              label: 'Avg Cost / Person',
              value: CurrencyFormatter.format(insights.averageCostPerPerson),
              color: Colors.orange,
              colorScheme: colorScheme,
            )),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(
              icon: Icons.date_range_rounded,
              label: 'Trip Duration',
              value: insights.tripDurationDays != null
                  ? '${insights.tripDurationDays} day${insights.tripDurationDays == 1 ? '' : 's'}'
                  : 'N/A',
              color: Colors.purple,
              colorScheme: colorScheme,
            )),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatCard(
              icon: Icons.trending_up_rounded,
              label: 'Avg Spend / Day',
              value: CurrencyFormatter.format(insights.averageSpendPerDay),
              color: Colors.green,
              colorScheme: colorScheme,
            )),
            const SizedBox(width: 10),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryInsights(TripInsights insights, String tripId, ColorScheme colorScheme) {
    final catInfo = ref.watch(categoryInfoProvider(tripId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _highlightRow(
              Icons.trending_up_rounded,
              'Highest',
              insights.highestSpendingCategory ?? 'N/A',
              CurrencyFormatter.format(insights.highestSpendingCategoryAmount),
              Colors.green,
              colorScheme,
            ),
            const Divider(height: 24),
            _highlightRow(
              Icons.trending_down_rounded,
              'Lowest',
              insights.lowestSpendingCategory ?? 'N/A',
              CurrencyFormatter.format(insights.lowestSpendingCategoryAmount),
              Colors.red,
              colorScheme,
            ),
            const Divider(height: 24),
            Text(
              'Category Breakdown',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...insights.categoryPercentages.entries.map((e) {
              final cat = catInfo[e.key];
              final pct = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: cat?.color ?? Colors.grey,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(e.key, style: const TextStyle(fontSize: 13)),
                        ),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        color: cat?.color ?? Colors.grey,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantInsights(TripInsights insights, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _highlightRow(
              Icons.paid_rounded,
              'Most Paid',
              insights.whoPaidTheMost ?? 'N/A',
              CurrencyFormatter.format(insights.whoPaidTheMostAmount),
              Colors.orange,
              colorScheme,
            ),
            const Divider(height: 24),
            _highlightRow(
              Icons.account_balance_rounded,
              'Owes Most',
              insights.whoOwesTheMost ?? 'N/A',
              CurrencyFormatter.format(insights.whoOwesTheMostAmount),
              Colors.red,
              colorScheme,
            ),
            const Divider(height: 24),
            _highlightRow(
              Icons.account_balance_wallet_rounded,
              'Receives Most',
              insights.whoReceivedTheMost ?? 'N/A',
              CurrencyFormatter.format(insights.whoReceivedTheMostAmount),
              Colors.green,
              colorScheme,
            ),
            const Divider(height: 24),
            _infoRow(
              Icons.group_rounded,
              'Avg Contribution / Person',
              CurrencyFormatter.format(insights.averageContributionPerParticipant),
              colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseInsights(TripInsights insights, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _highlightRow(
              Icons.arrow_upward_rounded,
              'Highest Expense',
              insights.highestExpenseName.isNotEmpty
                  ? insights.highestExpenseName
                  : 'N/A',
              CurrencyFormatter.format(insights.highestSingleExpense),
              Colors.red,
              colorScheme,
            ),
            const Divider(height: 24),
            _highlightRow(
              Icons.arrow_downward_rounded,
              'Lowest Expense',
              insights.lowestExpenseName.isNotEmpty
                  ? insights.lowestExpenseName
                  : 'N/A',
              CurrencyFormatter.format(insights.lowestSingleExpense),
              Colors.green,
              colorScheme,
            ),
            const Divider(height: 24),
            _infoRow(
              Icons.category_rounded,
              'Most Frequent Category',
              '${insights.mostFrequentCategory} (${insights.mostFrequentCategoryCount}x)',
              colorScheme,
            ),
            if (insights.mostUsedTemplate != null) ...[
              const Divider(height: 24),
              _infoRow(
                Icons.description_rounded,
                'Most Used Template',
                '${insights.mostUsedTemplate} (${insights.mostUsedTemplateCount}x)',
                colorScheme,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(TripInsights insights, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (insights.dailySpending.isNotEmpty) ...[
              Text(
                'Daily Spending',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ...insights.dailySpending.map((day) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            DateFormatter.formatShort(day.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: insights.dailySpending.isNotEmpty
                                  ? day.amount / insights.dailySpending
                                      .map((d) => d.amount)
                                      .reduce((a, b) => a > b ? a : b)
                                  : 0,
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              color: colorScheme.primary,
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: Text(
                            CurrencyFormatter.format(day.amount),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              if (insights.weeklySpending.length > 1) ...[
                const SizedBox(height: 20),
                Text(
                  'Weekly Spending',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                ...insights.weeklySpending.map((week) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              'Week ${week.weekNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: insights.weeklySpending.isNotEmpty
                                    ? week.amount / insights.weeklySpending
                                        .map((w) => w.amount)
                                        .reduce((a, b) => a > b ? a : b)
                                    : 0,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                color: colorScheme.tertiary,
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: Text(
                              CurrencyFormatter.format(week.amount),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
            if (insights.dailySpending.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No spending data to display',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartInsights(TripInsights insights, ColorScheme colorScheme) {
    if (insights.smartInsights.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Add expenses to generate smart insights.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: insights.smartInsights.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _highlightRow(
    IconData icon,
    String label,
    String name,
    String amount,
    Color accentColor,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accentColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Future<void> _handleExport(
      BuildContext context, String format, String tripId) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      if (format == 'pdf') {
        await _exportPdf(tripId);
      } else {
        await _exportPng();
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPng() async {
    final boundary = _repaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/insights_$timestamp.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());

    if (mounted) {
      await Share.shareXFiles([XFile(file.path)], text: 'Trip Insights');
    }
  }

  Future<void> _exportPdf(String tripId) async {
    final insights = ref.read(tripInsightsProvider(tripId));

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Trip Insights',
                style: pw.TextStyle(
                    fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: 'Overview'),
          pw.SizedBox(height: 8),
          _pdfRow('Total Trip Cost', '\$${insights.totalTripCost.toStringAsFixed(2)}'),
          _pdfRow('Participants', '${insights.totalParticipants}'),
          _pdfRow('Total Expenses', '${insights.totalExpenses}'),
          _pdfRow('Average Expense', '\$${insights.averageExpense.toStringAsFixed(2)}'),
          _pdfRow('Avg Cost / Person', '\$${insights.averageCostPerPerson.toStringAsFixed(2)}'),
          _pdfRow('Trip Duration',
              insights.tripDurationDays != null ? '${insights.tripDurationDays} days' : 'N/A'),
          _pdfRow('Avg Spend / Day', '\$${insights.averageSpendPerDay.toStringAsFixed(2)}'),
          pw.SizedBox(height: 24),
          pw.Header(level: 1, text: 'Category Insights'),
          pw.SizedBox(height: 8),
          _pdfRow('Highest', '${insights.highestSpendingCategory ?? 'N/A'} (\$${insights.highestSpendingCategoryAmount.toStringAsFixed(2)})'),
          _pdfRow('Lowest', '${insights.lowestSpendingCategory ?? 'N/A'} (\$${insights.lowestSpendingCategoryAmount.toStringAsFixed(2)})'),
          pw.SizedBox(height: 8),
          ...insights.categoryPercentages.entries.map((e) =>
              _pdfRow(e.key, '${e.value.toStringAsFixed(1)}%')),
          pw.SizedBox(height: 24),
          pw.Header(level: 1, text: 'Participant Insights'),
          pw.SizedBox(height: 8),
          _pdfRow('Most Paid', '${insights.whoPaidTheMost ?? 'N/A'} (\$${insights.whoPaidTheMostAmount.toStringAsFixed(2)})'),
          _pdfRow('Owes Most', '${insights.whoOwesTheMost ?? 'N/A'} (\$${insights.whoOwesTheMostAmount.toStringAsFixed(2)})'),
          _pdfRow('Receives Most', '${insights.whoReceivedTheMost ?? 'N/A'} (\$${insights.whoReceivedTheMostAmount.toStringAsFixed(2)})'),
          _pdfRow('Avg Contribution', '\$${insights.averageContributionPerParticipant.toStringAsFixed(2)}'),
          pw.SizedBox(height: 24),
          pw.Header(level: 1, text: 'Expense Insights'),
          pw.SizedBox(height: 8),
          _pdfRow('Highest', '${insights.highestExpenseName} (\$${insights.highestSingleExpense.toStringAsFixed(2)})'),
          _pdfRow('Lowest', '${insights.lowestExpenseName} (\$${insights.lowestSingleExpense.toStringAsFixed(2)})'),
          _pdfRow('Most Frequent Category', '${insights.mostFrequentCategory} (${insights.mostFrequentCategoryCount}x)'),
          if (insights.mostUsedTemplate != null)
            _pdfRow('Most Used Template', '${insights.mostUsedTemplate} (${insights.mostUsedTemplateCount}x)'),
          pw.SizedBox(height: 24),
          pw.Header(level: 1, text: 'Smart Insights'),
          pw.SizedBox(height: 8),
          ...insights.smartInsights.map((insight) =>
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text('- $insight',
                    style: const pw.TextStyle(fontSize: 11)),
              )),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/insights_$timestamp.pdf');
    await file.writeAsBytes(await pdf.save());

    if (mounted) {
      await Share.shareXFiles([XFile(file.path)], text: 'Trip Insights');
    }
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ColorScheme colorScheme;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

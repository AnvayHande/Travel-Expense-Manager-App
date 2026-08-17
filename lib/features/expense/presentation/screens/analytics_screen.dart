import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/models/category_model.dart';
import '../../../../presentation/providers/expense_filter_provider.dart';
import '../../../../presentation/providers/category_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';
    final analytics = ref.watch(analyticsProvider(tripId));
    final catInfo = ref.watch(categoryInfoProvider(tripId));

    return Scaffold(
      appBar: const CustomAppBar(title: 'Analytics'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsGrid(analytics, colorScheme),
            const SizedBox(height: 24),
            _buildCategoryPieChart(analytics, catInfo, colorScheme),
            const SizedBox(height: 24),
            _buildParticipantBarChart(analytics, colorScheme),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(AnalyticsData analytics, ColorScheme colorScheme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.receipt_rounded,
                label: 'Total Expenses',
                value: CurrencyFormatter.format(analytics.totalExpenses),
                color: colorScheme.primary,
                colorScheme: colorScheme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.format_list_numbered_rounded,
                label: 'Count',
                value: '${analytics.expenseCount}',
                color: colorScheme.tertiary,
                colorScheme: colorScheme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.trending_up_rounded,
                label: 'Highest',
                value: CurrencyFormatter.format(analytics.highestExpense),
                color: Colors.orange,
                colorScheme: colorScheme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.calculate_rounded,
                label: 'Average',
                value: CurrencyFormatter.format(analytics.averageExpense),
                color: Colors.green,
                colorScheme: colorScheme,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryPieChart(
      AnalyticsData analytics, Map<String, CategoryModel> catInfo, ColorScheme colorScheme) {
    if (analytics.byCategory.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text('No expense data',
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
        ),
      );
    }

    final sections = analytics.byCategory.entries.map((entry) {
      final cat = catInfo[entry.key];
      return PieChartSectionData(
        value: entry.value,
        title: '${entry.key}\n${CurrencyFormatter.format(entry.value)}',
        titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
        color: cat?.color ?? Colors.grey,
        radius: 60,
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart_rounded,
                    size: 20, color: colorScheme.onSurface),
                const SizedBox(width: 8),
                Text(
                  'Expenses by Category',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 30,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...analytics.byCategory.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: catInfo[entry.key]?.color ?? Colors.grey,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(entry.key,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      Text(
                        CurrencyFormatter.format(entry.value),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantBarChart(
      AnalyticsData analytics, ColorScheme colorScheme) {
    if (analytics.byParticipant.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text('No participant data',
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
        ),
      );
    }

    final entries = analytics.byParticipant.entries.toList();
    final maxAmount = entries
        .map((e) => e.value)
        .reduce((a, b) => a > b ? a : b);

    final barColors = [
      colorScheme.primary,
      colorScheme.tertiary,
      colorScheme.secondary,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.brown,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded,
                    size: 20, color: colorScheme.onSurface),
                const SizedBox(width: 8),
                Text(
                  'Expenses by Participant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxAmount * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final name = analytics.participantNames[
                                entries[group.x.toInt()].key] ??
                            entries[group.x.toInt()].key;
                        return BarTooltipItem(
                          '$name\n${CurrencyFormatter.format(rod.toY)}',
                          const TextStyle(
                              color: Colors.white, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          final name = analytics.participantNames[
                                  entries[idx].key] ??
                              entries[idx].key;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              name.length > 3
                                  ? name.substring(0, 3)
                                  : name,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                        reservedSize: 24,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            CurrencyFormatter.format(value),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxAmount > 0 ? maxAmount / 4 : 1,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: entries.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final data = entry.value;
                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: data.value,
                          color: barColors[idx % barColors.length],
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
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
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
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

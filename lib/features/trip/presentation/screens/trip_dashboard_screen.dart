import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/models/category_model.dart';
import '../../../../presentation/providers/dashboard_provider.dart';
import '../../../../presentation/providers/category_provider.dart';

class TripDashboardScreen extends ConsumerWidget {
  const TripDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';
    final data = ref.watch(dashboardProvider(tripId));
    final catInfo = ref.watch(categoryInfoProvider(tripId));

    return Scaffold(
      appBar: const CustomAppBar(title: 'Dashboard'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsGrid(data, colorScheme),
            const SizedBox(height: 24),
            _buildInsights(data, colorScheme),
            const SizedBox(height: 24),
            _buildCategoryPieChart(data, catInfo, colorScheme),
            const SizedBox(height: 24),
            _buildParticipantBarChart(data, colorScheme),
            const SizedBox(height: 24),
            _buildDailyLineChart(data, colorScheme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(DashboardData data, ColorScheme colorScheme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.attach_money_rounded,
                label: 'Total Expenses',
                value: CurrencyFormatter.format(data.totalExpenses),
                color: colorScheme.primary,
                colorScheme: colorScheme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.people_outlined,
                label: 'Participants',
                value: '${data.participantCount}',
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
                icon: Icons.calculate_rounded,
                label: 'Average',
                value: CurrencyFormatter.format(data.averageExpense),
                color: Colors.green,
                colorScheme: colorScheme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.trending_up_rounded,
                label: 'Highest',
                value: CurrencyFormatter.format(data.highestExpense),
                color: Colors.orange,
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
                icon: Icons.trending_down_rounded,
                label: 'Lowest',
                value: CurrencyFormatter.format(data.lowestExpense),
                color: Colors.blue,
                colorScheme: colorScheme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.date_range_rounded,
                label: 'This Week',
                value: '${data.expensesThisWeek}',
                color: Colors.indigo,
                colorScheme: colorScheme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.calendar_month_rounded,
                label: 'This Month',
                value: '${data.expensesThisMonth}',
                color: Colors.teal,
                colorScheme: colorScheme,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsights(DashboardData data, ColorScheme colorScheme) {
    final insights = <String>[];

    if (data.insights.highestCategory != null) {
      insights.add(
        '${data.insights.highestCategory} is the highest expense category.',
      );
    }

    if (data.insights.highestPayerName.isNotEmpty) {
      insights.add(
        '${data.insights.highestPayerName} has paid the most.',
      );
    }

    insights.add(
      'Average expense per day is '
      '${CurrencyFormatter.format(double.parse(data.insights.averagePerDayText))}.',
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outlined,
                    size: 20, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text(
                  'Quick Insights',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...insights.map((text) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface,
                            height: 1.4,
                          ),
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

  Widget _buildCategoryPieChart(
      DashboardData data, Map<String, CategoryModel> catInfo, ColorScheme colorScheme) {
    if (data.byCategory.isEmpty) {
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

    final sections = data.byCategory.entries.map((entry) {
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
            ...data.byCategory.entries.map((entry) => Padding(
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
      DashboardData data, ColorScheme colorScheme) {
    if (data.byParticipant.isEmpty) {
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

    final entries = data.byParticipant.entries.toList();
    final maxAmount = entries
        .map((e) => e.value)
        .reduce((a, b) => a > b ? a : b);

    const barColors = [
      Colors.blue,
      Colors.teal,
      Colors.orange,
      Colors.pink,
      Colors.indigo,
      Colors.brown,
      Colors.purple,
      Colors.cyan,
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
                  'Amount by Participant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxAmount * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final uid = entries[group.x.toInt()].key;
                        final name = data.participantNames[uid] ?? uid;
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
                          final name = data.participantNames[
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
                    horizontalInterval:
                        maxAmount > 0 ? maxAmount / 4 : 1,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: entries.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final dataPoint = entry.value;
                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: dataPoint.value,
                          color:
                              barColors[idx % barColors.length],
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

  Widget _buildDailyLineChart(
      DashboardData data, ColorScheme colorScheme) {
    if (data.dailySpending.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text('No spending data',
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
        ),
      );
    }

    final spots = data.dailySpending.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.amount);
    }).toList();

    final maxY = spots.fold<double>(0, (p, s) => s.y > p ? s.y : p);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart_rounded,
                    size: 20, color: colorScheme.onSurface),
                const SizedBox(width: 8),
                Text(
                  'Daily Spending',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY * 1.3,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final idx = spot.x.toInt();
                          final day = idx >= 0 &&
                                  idx < data.dailySpending.length
                              ? data.dailySpending[idx]
                              : null;
                          return LineTooltipItem(
                            '${day != null ? '${day.date.month}/${day.date.day}' : ''}\n${CurrencyFormatter.format(spot.y)}',
                            const TextStyle(
                                color: Colors.white, fontSize: 12),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: colorScheme.primary,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: colorScheme.primary,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colorScheme.primary
                            .withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 ||
                              idx >= data.dailySpending.length) {
                            return const SizedBox.shrink();
                          }
                          final day = data.dailySpending[idx];
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${day.date.month}/${day.date.day}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                        reservedSize: 24,
                        interval: data.dailySpending.length > 10
                            ? (data.dailySpending.length / 5)
                                .ceilToDouble()
                            : 1,
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
                    horizontalInterval:
                        maxY > 0 ? maxY / 4 : 1,
                  ),
                  borderData: FlBorderData(show: false),
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
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/services/budget_service.dart';
import '../../../../presentation/providers/category_provider.dart';
import '../../../../presentation/providers/trip_provider.dart';

class BudgetDashboardScreen extends ConsumerWidget {
  const BudgetDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';
    final budget = ref.watch(budgetDataProvider(tripId));
    final tripAsync = ref.watch(tripByIdProvider(tripId));
    final trip = tripAsync.valueOrNull;

    return Scaffold(
      appBar: CustomAppBar(title: 'Budget Overview'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverallCard(budget, colorScheme),
            const SizedBox(height: 20),
            if (trip != null && trip.totalBudget > 0) ...[
              _buildBudgetProgress(budget, colorScheme),
              const SizedBox(height: 24),
            ],
            if (budget.warnings.isNotEmpty) ...[
              _buildWarnings(budget, colorScheme),
              const SizedBox(height: 24),
            ],
            if (budget.insights.isNotEmpty) ...[
              _buildInsights(budget, colorScheme),
              const SizedBox(height: 24),
            ],
            Text('Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            const SizedBox(height: 12),
            ...budget.categoryBudgets
                .where((c) => c.category.budget > 0 || c.spent > 0)
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildCategoryBudgetCard(c, colorScheme, tripId),
                    )),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallCard(BudgetData budget, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.account_balance_wallet_rounded, color: colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Budget', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(budget.totalBudget),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
            if (budget.totalBudget > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Spent', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                  Text(
                    CurrencyFormatter.format(budget.totalSpent),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: budget.utilizationPercent > 100 ? colorScheme.error : colorScheme.primary),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetProgress(BudgetData budget, ColorScheme colorScheme) {
    final color = budget.utilizationPercent > 100
        ? colorScheme.error
        : budget.utilizationPercent > 90
            ? Colors.orange
            : budget.utilizationPercent > 75
                ? Colors.amber
                : Colors.green;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart_rounded, size: 20, color: colorScheme.onSurface),
                const SizedBox(width: 8),
                Text('Budget Utilization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (budget.utilizationPercent / 100).clamp(0, 1),
                minHeight: 20,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${CurrencyFormatter.format(budget.totalSpent)} spent', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                Text('${budget.utilizationPercent.toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
            const SizedBox(height: 4),
            Text('${CurrencyFormatter.format(budget.remaining)} remaining',
                style: TextStyle(fontSize: 13, color: budget.remaining >= 0 ? Colors.green : colorScheme.error)),
          ],
        ),
      ),
    );
  }

  Widget _buildWarnings(BudgetData budget, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 20, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text('Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
              ],
            ),
            const Divider(height: 20),
            ...budget.warnings.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(Icons.circle, size: 8, color: Colors.orange.shade700),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(w, style: TextStyle(fontSize: 13, color: colorScheme.onSurface))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildInsights(BudgetData budget, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outlined, size: 20, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text('Suggestions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
              ],
            ),
            const Divider(height: 20),
            ...budget.insights.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber.shade700),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(i, style: TextStyle(fontSize: 13, color: colorScheme.onSurface))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBudgetCard(CategoryBudgetData cb, ColorScheme colorScheme, String tripId) {
    final color = cb.warningLevel == BudgetWarningLevel.exceeded
        ? colorScheme.error
        : cb.warningLevel == BudgetWarningLevel.critical
            ? Colors.orange
            : cb.warningLevel == BudgetWarningLevel.warning
                ? Colors.amber
                : cb.category.color;

    return Card(
      child: InkWell(
        onTap: () {
          // future: open category edit
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: cb.category.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(cb.category.icon, color: cb.category.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cb.category.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (cb.budget > 0)
                          Text(
                            '${CurrencyFormatter.format(cb.spent)} / ${CurrencyFormatter.format(cb.budget)}',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  if (cb.budget > 0)
                    Text('${cb.percentUsed.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                ],
              ),
              if (cb.budget > 0) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (cb.percentUsed / 100).clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

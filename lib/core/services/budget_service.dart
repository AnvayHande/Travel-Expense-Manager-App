import '../models/category_model.dart';
import '../models/expense_model.dart';

enum BudgetWarningLevel { none, warning, critical, exceeded }

class CategoryBudgetData {
  final CategoryModel category;
  final double spent;
  final double budget;
  final double percentUsed;
  final BudgetWarningLevel warningLevel;

  const CategoryBudgetData({
    required this.category,
    required this.spent,
    required this.budget,
    required this.percentUsed,
    required this.warningLevel,
  });
}

class BudgetData {
  final double totalBudget;
  final double totalSpent;
  final double remaining;
  final double utilizationPercent;
  final List<CategoryBudgetData> categoryBudgets;
  final List<String> warnings;
  final List<String> insights;

  const BudgetData({
    required this.totalBudget,
    required this.totalSpent,
    required this.remaining,
    required this.utilizationPercent,
    required this.categoryBudgets,
    required this.warnings,
    required this.insights,
  });
}

class BudgetService {
  BudgetData calculate({
    required List<CategoryModel> categories,
    required List<ExpenseModel> expenses,
    required double totalBudget,
  }) {
    final activeCategories = categories.where((c) => !c.isArchived).toList();
    final warnings = <String>[];
    final insights = <String>[];
    final categoryBudgets = <CategoryBudgetData>[];

    final spentByCategory = <String, double>{};
    for (final expense in expenses) {
      spentByCategory[expense.category] =
          (spentByCategory[expense.category] ?? 0.0) + expense.amount;
    }

    double totalSpent = 0.0;
    for (final cat in activeCategories) {
      final spent = spentByCategory[cat.name] ?? 0;
      totalSpent += spent;
      final budget = cat.budget;
      final percentUsed = budget > 0 ? (spent / budget) * 100 : 0.0;
      final warningLevel = _getWarningLevel(percentUsed, budget);

      if (warningLevel != BudgetWarningLevel.none && budget > 0) {
        if (warningLevel == BudgetWarningLevel.exceeded) {
          warnings.add('${cat.name} budget exceeded: spent ${spent.toStringAsFixed(2)} of ${budget.toStringAsFixed(2)}');
        } else if (warningLevel == BudgetWarningLevel.critical) {
          warnings.add('${cat.name} is at ${percentUsed.toStringAsFixed(0)}% of budget');
        } else if (warningLevel == BudgetWarningLevel.warning) {
          warnings.add('${cat.name} approaching budget limit (${percentUsed.toStringAsFixed(0)}%)');
        }
      }

      categoryBudgets.add(CategoryBudgetData(
        category: cat,
        spent: spent,
        budget: budget,
        percentUsed: percentUsed,
        warningLevel: warningLevel,
      ));
    }

    if (totalBudget > 0) {
      if (totalSpent > totalBudget) {
        warnings.insert(0, 'Total budget exceeded by ${(totalSpent - totalBudget).toStringAsFixed(2)}');
      } else if (totalSpent > totalBudget * 0.9) {
        warnings.insert(0, 'Total spending at ${((totalSpent / totalBudget) * 100).toStringAsFixed(0)}% of budget');
      }

      final remaining = totalBudget - totalSpent;
      if (remaining > 0) {
        final remainingDays = _estimateRemainingDays(expenses);
        if (remainingDays > 0) {
          final perDay = remaining / remainingDays;
          if (perDay > 0) {
            insights.add('You can spend ${perDay.toStringAsFixed(2)} per day for the next $remainingDays days');
          }
        }
      }
    }

    final highestCat = categoryBudgets.fold<CategoryBudgetData?>(null, (max, c) {
      if (c.budget == 0) return max;
      return (max == null || c.percentUsed > max.percentUsed) ? c : max;
    });
    if (highestCat != null && highestCat.percentUsed > 0) {
      insights.add('${highestCat.category.name} has the highest budget utilization at ${highestCat.percentUsed.toStringAsFixed(0)}%');
    }

    final unsavedCats = activeCategories.where((c) => c.budget == 0 && (spentByCategory[c.name] ?? 0) > 0).toList();
    for (final cat in unsavedCats) {
      insights.add('Set a budget for ${cat.name} (${(spentByCategory[cat.name] ?? 0).toStringAsFixed(2)} spent)');
    }

    final utilizationPercent = totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0.0;
    final remaining = totalBudget - totalSpent;

    return BudgetData(
      totalBudget: totalBudget,
      totalSpent: totalSpent,
      remaining: remaining,
      utilizationPercent: utilizationPercent,
      categoryBudgets: categoryBudgets,
      warnings: warnings,
      insights: insights,
    );
  }

  BudgetWarningLevel _getWarningLevel(double percentUsed, double budget) {
    if (budget <= 0) return BudgetWarningLevel.none;
    if (percentUsed >= 100) return BudgetWarningLevel.exceeded;
    if (percentUsed >= 90) return BudgetWarningLevel.critical;
    if (percentUsed >= 75) return BudgetWarningLevel.warning;
    return BudgetWarningLevel.none;
  }

  int _estimateRemainingDays(List<ExpenseModel> expenses) {
    if (expenses.length < 2) return 7;
    final dates = expenses.map((e) => e.createdAt).toList()..sort();
    final oldest = dates.first;
    final newest = dates.last;
    final span = newest.difference(oldest).inDays;
    if (span <= 0) return 7;
    return ((newest.difference(oldest).inDays / expenses.length) * 30).round().clamp(1, 365);
  }
}

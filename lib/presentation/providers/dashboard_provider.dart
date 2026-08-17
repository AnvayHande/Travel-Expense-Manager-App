import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/expense_filter_service.dart';
import '../../core/services/analytics_service.dart';
import 'expense_provider.dart';
import 'trip_provider.dart';
import 'firebase_providers.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(filterService: ExpenseFilterService());
});

class DashboardData {
  final double totalExpenses;
  final int expenseCount;
  final int participantCount;
  final double highestExpense;
  final double lowestExpense;
  final double averageExpense;
  final int expensesThisWeek;
  final int expensesThisMonth;
  final Map<String, double> byCategory;
  final Map<String, double> byParticipant;
  final Map<String, String> participantNames;
  final List<DailySpending> dailySpending;
  final InsightsData insights;

  const DashboardData({
    required this.totalExpenses,
    required this.expenseCount,
    required this.participantCount,
    required this.highestExpense,
    required this.lowestExpense,
    required this.averageExpense,
    required this.expensesThisWeek,
    required this.expensesThisMonth,
    required this.byCategory,
    required this.byParticipant,
    required this.participantNames,
    required this.dailySpending,
    required this.insights,
  });
}

final dashboardProvider =
    Provider.family<DashboardData, String>((ref, tripId) {
  final expensesAsync = ref.watch(tripExpensesProvider(tripId));
  final expenses = expensesAsync.valueOrNull ?? [];
  final tripAsync = ref.watch(tripByIdProvider(tripId));
  final trip = tripAsync.valueOrNull;

  final expenseFilterService = ExpenseFilterService();
  final analyticsService = ref.watch(analyticsServiceProvider);

  final participantNames = <String, String>{};
  final participants = trip?.participants ?? [];
  for (final uid in participants) {
    final nameAsync = ref.watch(userNameProvider(uid));
    participantNames[uid] = nameAsync.valueOrNull ?? uid;
  }

  final byCategory = expenseFilterService.expensesByCategory(expenses);
  final byParticipant = participants.isNotEmpty
      ? expenseFilterService.expensesByParticipant(
          expenses, participants, participantNames)
      : <String, double>{};

  final dailySpending = analyticsService.dailySpending(expenses);

  final insights = analyticsService.generateInsights(
    byCategory: byCategory,
    byParticipant: byParticipant,
    participantNames: participantNames,
    expenses: expenses,
    tripStartDate: trip?.startDate,
    tripEndDate: trip?.endDate,
  );

  return DashboardData(
    totalExpenses: expenseFilterService.totalExpenses(expenses),
    expenseCount: expenses.length,
    participantCount: participants.length,
    highestExpense: expenseFilterService.highestExpense(expenses),
    lowestExpense: analyticsService.lowestExpense(expenses),
    averageExpense: expenseFilterService.averageExpense(expenses),
    expensesThisWeek: insights.expensesThisWeek,
    expensesThisMonth: insights.expensesThisMonth,
    byCategory: byCategory,
    byParticipant: byParticipant,
    participantNames: participantNames,
    dailySpending: dailySpending,
    insights: insights,
  );
});

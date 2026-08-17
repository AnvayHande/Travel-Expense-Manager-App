import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/insights_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/expense_filter_service.dart';
import 'expense_provider.dart';
import 'trip_provider.dart';
import 'firebase_providers.dart';
import 'settlement_provider.dart';
import 'template_provider.dart';

final insightsServiceProvider = Provider<InsightsService>((ref) {
  return InsightsService(
    filterService: ExpenseFilterService(),
    analyticsService: AnalyticsService(filterService: ExpenseFilterService()),
  );
});

final tripInsightsProvider =
    Provider.family<TripInsights, String>((ref, tripId) {
  final expensesAsync = ref.watch(tripExpensesProvider(tripId));
  final expenses = expensesAsync.valueOrNull ?? [];
  final tripAsync = ref.watch(tripByIdProvider(tripId));
  final trip = tripAsync.valueOrNull;
  final balances = ref.watch(tripBalanceProvider(tripId));
  final templatesAsync = ref.watch(userTemplatesProvider);
  final templates = templatesAsync.valueOrNull ?? [];

  final participantNames = <String, String>{};
  final participants = trip?.participants ?? [];
  for (final uid in participants) {
    final nameAsync = ref.watch(userNameProvider(uid));
    participantNames[uid] = nameAsync.valueOrNull ?? uid;
  }

  final paidByUser = <String, double>{};
  final owedByUser = <String, double>{};
  if (balances != null) {
    for (final entry in balances.entries) {
      paidByUser[entry.key] = entry.value.totalPaid;
      owedByUser[entry.key] = entry.value.totalOwed;
    }
  }

  final service = ref.watch(insightsServiceProvider);
  return service.generate(
    expenses: expenses,
    participants: participants,
    participantNames: participantNames,
    paidByUser: paidByUser,
    owedByUser: owedByUser,
    tripStartDate: trip?.startDate,
    tripEndDate: trip?.endDate,
    templates: templates,
  );
});

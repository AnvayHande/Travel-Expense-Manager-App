import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/expense_model.dart';
import '../../core/services/expense_filter_service.dart';
import 'expense_provider.dart';
import 'trip_provider.dart';
import 'authentication_provider.dart';
import 'firebase_providers.dart';

class FilterState {
  final String searchQuery;
  final String? categoryFilter;
  final DateTime? dateStart;
  final DateTime? dateEnd;
  final String? paidByFilter;
  final double? amountMin;
  final double? amountMax;
  final bool onlyMyExpenses;
  final bool onlyMyParticipations;
  final SortOption sortOption;

  const FilterState({
    this.searchQuery = '',
    this.categoryFilter,
    this.dateStart,
    this.dateEnd,
    this.paidByFilter,
    this.amountMin,
    this.amountMax,
    this.onlyMyExpenses = false,
    this.onlyMyParticipations = false,
    this.sortOption = SortOption.newest,
  });

  FilterState copyWith({
    String? searchQuery,
    String? categoryFilter,
    DateTime? dateStart,
    DateTime? dateEnd,
    String? paidByFilter,
    double? amountMin,
    double? amountMax,
    bool? onlyMyExpenses,
    bool? onlyMyParticipations,
    SortOption? sortOption,
    bool clearCategory = false,
    bool clearPaidBy = false,
    bool clearDateStart = false,
    bool clearDateEnd = false,
    bool clearAmountMin = false,
    bool clearAmountMax = false,
  }) {
    return FilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      categoryFilter: clearCategory ? null : (categoryFilter ?? this.categoryFilter),
      dateStart: clearDateStart ? null : (dateStart ?? this.dateStart),
      dateEnd: clearDateEnd ? null : (dateEnd ?? this.dateEnd),
      paidByFilter: clearPaidBy ? null : (paidByFilter ?? this.paidByFilter),
      amountMin: clearAmountMin ? null : (amountMin ?? this.amountMin),
      amountMax: clearAmountMax ? null : (amountMax ?? this.amountMax),
      onlyMyExpenses: onlyMyExpenses ?? this.onlyMyExpenses,
      onlyMyParticipations:
          onlyMyParticipations ?? this.onlyMyParticipations,
      sortOption: sortOption ?? this.sortOption,
    );
  }

  void reset() {
    // handled by the notifier
  }
}

class FilterNotifier extends StateNotifier<FilterState> {
  FilterNotifier() : super(const FilterState());

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCategory(String? category) {
    state = state.copyWith(categoryFilter: category);
  }

  void clearCategory() {
    state = state.copyWith(clearCategory: true);
  }

  void setDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(dateStart: start, dateEnd: end);
  }

  void clearDateRange() {
    state = state.copyWith(clearDateStart: true, clearDateEnd: true);
  }

  void setPaidBy(String? uid) {
    state = state.copyWith(paidByFilter: uid);
  }

  void clearPaidBy() {
    state = state.copyWith(clearPaidBy: true);
  }

  void setAmountRange(double? min, double? max) {
    state = state.copyWith(amountMin: min, amountMax: max);
  }

  void clearAmountRange() {
    state = state.copyWith(clearAmountMin: true, clearAmountMax: true);
  }

  void toggleMyExpenses() {
    state = state.copyWith(onlyMyExpenses: !state.onlyMyExpenses);
  }

  void toggleMyParticipations() {
    state = state.copyWith(
        onlyMyParticipations: !state.onlyMyParticipations);
  }

  void setSort(SortOption option) {
    state = state.copyWith(sortOption: option);
  }

  void resetAll() {
    state = const FilterState();
  }
}

final filterProvider =
    StateNotifierProvider<FilterNotifier, FilterState>((ref) {
  return FilterNotifier();
});

final filteredExpensesProvider =
    Provider.family<List<ExpenseModel>, String>((ref, tripId) {
  final expensesAsync = ref.watch(tripExpensesProvider(tripId));
  final expenses = expensesAsync.valueOrNull ?? [];
  final filter = ref.watch(filterProvider);
  final tripAsync = ref.watch(tripByIdProvider(tripId));
  final trip = tripAsync.valueOrNull;
  final currentUser = ref.watch(authProvider).user;

  if (trip == null) return [];

  final participantNames = <String, String>{};
  for (final uid in trip.participants) {
    final nameAsync = ref.watch(userNameProvider(uid));
    participantNames[uid] = nameAsync.valueOrNull ?? uid;
  }

  final service = ExpenseFilterService();
  return service.apply(
    expenses: expenses,
    searchQuery: filter.searchQuery,
    categoryFilter: filter.categoryFilter,
    dateStart: filter.dateStart,
    dateEnd: filter.dateEnd,
    paidByFilter: filter.paidByFilter,
    amountMin: filter.amountMin,
    amountMax: filter.amountMax,
    onlyMyExpenses: filter.onlyMyExpenses,
    onlyMyParticipations: filter.onlyMyParticipations,
    currentUserId: currentUser?.uid,
    participantNames: participantNames,
    sortOption: filter.sortOption,
  );
});

final analyticsProvider =
    Provider.family<AnalyticsData, String>((ref, tripId) {
  final expensesAsync = ref.watch(tripExpensesProvider(tripId));
  final expenses = expensesAsync.valueOrNull ?? [];
  final tripAsync = ref.watch(tripByIdProvider(tripId));
  final trip = tripAsync.valueOrNull;

  final service = ExpenseFilterService();

  final participantNames = <String, String>{};
  if (trip != null) {
    for (final uid in trip.participants) {
      final nameAsync = ref.watch(userNameProvider(uid));
      participantNames[uid] = nameAsync.valueOrNull ?? uid;
    }
  }

  return AnalyticsData(
    totalExpenses: service.totalExpenses(expenses),
    expenseCount: expenses.length,
    highestExpense: service.highestExpense(expenses),
    averageExpense: service.averageExpense(expenses),
    byCategory: service.expensesByCategory(expenses),
    byParticipant: trip != null
        ? service.expensesByParticipant(
            expenses, trip.participants, participantNames)
        : {},
    participantNames: participantNames,
  );
});

class AnalyticsData {
  final double totalExpenses;
  final int expenseCount;
  final double highestExpense;
  final double averageExpense;
  final Map<String, double> byCategory;
  final Map<String, double> byParticipant;
  final Map<String, String> participantNames;

  const AnalyticsData({
    required this.totalExpenses,
    required this.expenseCount,
    required this.highestExpense,
    required this.averageExpense,
    required this.byCategory,
    required this.byParticipant,
    required this.participantNames,
  });
}

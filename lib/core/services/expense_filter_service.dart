import '../models/expense_model.dart';

enum SortOption {
  newest,
  oldest,
  highestAmount,
  lowestAmount,
  alphabetical,
}

class ExpenseFilterService {
  List<ExpenseModel> apply({
    required List<ExpenseModel> expenses,
    required String searchQuery,
    required String? categoryFilter,
    required DateTime? dateStart,
    required DateTime? dateEnd,
    required String? paidByFilter,
    required double? amountMin,
    required double? amountMax,
    required bool onlyMyExpenses,
    required bool onlyMyParticipations,
    required String? currentUserId,
    required Map<String, String> participantNames,
    required SortOption sortOption,
  }) {
    var result = expenses;

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result = result.where((e) {
        final nameMatch = e.expenseName.toLowerCase().contains(query);
        final notesMatch =
            e.notes?.toLowerCase().contains(query) ?? false;
        final payerName =
            (participantNames[e.paidBy] ?? e.paidBy).toLowerCase();
        final payerMatch = payerName.contains(query);
        return nameMatch || notesMatch || payerMatch;
      }).toList();
    }

    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      result =
          result.where((e) => e.category == categoryFilter).toList();
    }

    if (dateStart != null) {
      result = result
          .where((e) =>
              e.createdAt.isAfter(dateStart.subtract(const Duration(days: 1))))
          .toList();
    }

    if (dateEnd != null) {
      result = result
          .where((e) =>
              e.createdAt.isBefore(dateEnd.add(const Duration(days: 1))))
          .toList();
    }

    if (paidByFilter != null && paidByFilter.isNotEmpty) {
      result =
          result.where((e) => e.paidBy == paidByFilter).toList();
    }

    if (amountMin != null) {
      result = result.where((e) => e.amount >= amountMin).toList();
    }

    if (amountMax != null) {
      result = result.where((e) => e.amount <= amountMax).toList();
    }

    if (onlyMyExpenses && currentUserId != null) {
      result =
          result.where((e) => e.paidBy == currentUserId).toList();
    }

    if (onlyMyParticipations && currentUserId != null) {
      result = result
          .where((e) => e.splitBetween.contains(currentUserId))
          .toList();
    }

    result = List.from(result);
    switch (sortOption) {
      case SortOption.newest:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case SortOption.oldest:
        result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case SortOption.highestAmount:
        result.sort((a, b) => b.amount.compareTo(a.amount));
      case SortOption.lowestAmount:
        result.sort((a, b) => a.amount.compareTo(b.amount));
      case SortOption.alphabetical:
        result.sort((a, b) => a.expenseName.compareTo(b.expenseName));
    }

    return result;
  }

  Map<String, double> expensesByCategory(List<ExpenseModel> expenses) {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  Map<String, double> expensesByParticipant(
      List<ExpenseModel> expenses, List<String> participants,
      Map<String, String> participantNames) {
    final map = <String, double>{};
    for (final uid in participants) {
      map[uid] = 0;
    }
    for (final e in expenses) {
      map[e.paidBy] = (map[e.paidBy] ?? 0) + e.amount;
    }
    return map;
  }

  double totalExpenses(List<ExpenseModel> expenses) {
    return expenses.fold<double>(0, (sum, e) => sum + e.amount);
  }

  double highestExpense(List<ExpenseModel> expenses) {
    if (expenses.isEmpty) return 0;
    return expenses.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
  }

  double averageExpense(List<ExpenseModel> expenses) {
    if (expenses.isEmpty) return 0;
    return totalExpenses(expenses) / expenses.length;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/category_model.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/services/category_service.dart';
import '../../core/services/budget_service.dart';
import 'expense_provider.dart';
import 'firebase_providers.dart';
import 'trip_provider.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return FirebaseCategoryRepository(firestoreService: firestoreService);
});

final categoryServiceProvider = Provider<CategoryService>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return CategoryService(categoryRepository: repository);
});

final budgetServiceProvider = Provider<BudgetService>((ref) {
  return BudgetService();
});

final tripCategoriesProvider =
    StreamProvider.family<List<CategoryModel>, String>((ref, tripId) {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getTripCategories(tripId);
});

final mergedCategoriesProvider =
    Provider.family<List<CategoryModel>, String>((ref, tripId) {
  final categoriesAsync = ref.watch(tripCategoriesProvider(tripId));
  return categoriesAsync.valueOrNull ?? [];
});

final activeCategoriesProvider =
    Provider.family<List<CategoryModel>, String>((ref, tripId) {
  final categories = ref.watch(mergedCategoriesProvider(tripId));
  return categories.where((c) => !c.isArchived).toList();
});

final categoryInfoProvider = Provider.family<Map<String, CategoryModel>, String>((ref, tripId) {
  final categories = ref.watch(mergedCategoriesProvider(tripId));
  return {for (final c in categories) c.name: c};
});

final budgetDataProvider =
    Provider.family<BudgetData, String>((ref, tripId) {
  final categories = ref.watch(mergedCategoriesProvider(tripId));
  final expensesAsync = ref.watch(tripExpensesProvider(tripId));
  final expenses = expensesAsync.valueOrNull ?? [];
  final tripAsync = ref.watch(tripByIdProvider(tripId));
  final trip = tripAsync.valueOrNull;

  final budgetService = ref.watch(budgetServiceProvider);
  return budgetService.calculate(
    categories: categories,
    expenses: expenses,
    totalBudget: trip?.totalBudget ?? 0,
  );
});

final categoryNamesProvider = Provider.family<List<String>, String>((ref, tripId) {
  final categories = ref.watch(activeCategoriesProvider(tripId));
  return categories.map((c) => c.name).toList();
});

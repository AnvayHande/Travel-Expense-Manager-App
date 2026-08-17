import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/expense_template_model.dart';
import '../../core/repositories/template_repository.dart';
import '../../core/services/template_service.dart';
import 'authentication_provider.dart';
import 'firebase_providers.dart';

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return FirebaseTemplateRepository(firestoreService: firestoreService);
});

final templateServiceProvider = Provider<TemplateService>((ref) {
  final repository = ref.watch(templateRepositoryProvider);
  return TemplateService(templateRepository: repository);
});

final userTemplatesProvider = StreamProvider<List<ExpenseTemplateModel>>((ref) {
  final user = ref.watch(authProvider).user;
  if (user == null) return Stream.value([]);
  final repository = ref.watch(templateRepositoryProvider);
  return repository.getUserTemplates(user.uid);
});

final tripTemplatesProvider =
    Provider.family<List<ExpenseTemplateModel>, String>((ref, tripId) {
  final templatesAsync = ref.watch(userTemplatesProvider);
  final templates = templatesAsync.valueOrNull ?? [];
  return templates.where((t) => t.tripId == null || t.tripId == tripId).toList();
});

final globalTemplatesProvider = Provider<List<ExpenseTemplateModel>>((ref) {
  final templatesAsync = ref.watch(userTemplatesProvider);
  final templates = templatesAsync.valueOrNull ?? [];
  return templates.where((t) => t.tripId == null).toList();
});

final favoriteTemplatesProvider = Provider<List<ExpenseTemplateModel>>((ref) {
  final templatesAsync = ref.watch(userTemplatesProvider);
  final templates = templatesAsync.valueOrNull ?? [];
  return templates.where((t) => t.favorite).toList();
});

final recentlyUsedTemplatesProvider =
    Provider.family<List<ExpenseTemplateModel>, String>((ref, tripId) {
  final templatesAsync = ref.watch(userTemplatesProvider);
  final templates = templatesAsync.valueOrNull ?? [];
  final relevant = templates.where((t) => t.tripId == null || t.tripId == tripId).toList();
  relevant.sort((a, b) => b.usageCount.compareTo(a.usageCount));
  return relevant.take(5).toList();
});

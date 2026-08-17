import 'package:uuid/uuid.dart';
import '../models/expense_template_model.dart';
import '../repositories/template_repository.dart';

class TemplateService {
  final TemplateRepository _templateRepository;

  TemplateService({required TemplateRepository templateRepository})
      : _templateRepository = templateRepository;

  Future<void> createTemplate({
    required String userId,
    String? tripId,
    required String name,
    required String category,
    String splitType = 'equal',
    String? notes,
  }) async {
    final template = ExpenseTemplateModel(
      templateId: const Uuid().v4(),
      userId: userId,
      tripId: tripId,
      name: name,
      category: category,
      splitType: splitType,
      notes: notes,
      createdAt: DateTime.now(),
    );
    await _templateRepository.addTemplate(template);
  }

  Future<void> updateTemplate(ExpenseTemplateModel template) async {
    await _templateRepository.updateTemplate(template);
  }

  Future<void> deleteTemplate(String templateId) async {
    await _templateRepository.deleteTemplate(templateId);
  }

  Future<void> duplicateTemplate(ExpenseTemplateModel template) async {
    final duplicate = template.copyWith(
      templateId: const Uuid().v4(),
      name: '${template.name} (copy)',
      usageCount: 0,
      createdAt: DateTime.now(),
    );
    await _templateRepository.addTemplate(duplicate);
  }

  Future<void> toggleFavorite(String templateId, bool favorite) async {
    await _templateRepository.toggleFavorite(templateId, favorite);
  }

  Future<void> recordUsage(String templateId) async {
    await _templateRepository.incrementUsage(templateId);
  }
}

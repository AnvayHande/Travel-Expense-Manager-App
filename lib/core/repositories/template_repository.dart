import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_template_model.dart';
import '../services/firestore_service.dart';

abstract class TemplateRepository {
  Stream<List<ExpenseTemplateModel>> getUserTemplates(String userId);
  Stream<List<ExpenseTemplateModel>> getTripTemplates(String userId, String tripId);
  Future<void> addTemplate(ExpenseTemplateModel template);
  Future<void> updateTemplate(ExpenseTemplateModel template);
  Future<void> deleteTemplate(String templateId);
  Future<void> incrementUsage(String templateId);
  Future<void> toggleFavorite(String templateId, bool favorite);
}

class FirebaseTemplateRepository implements TemplateRepository {
  final FirestoreService _firestoreService;

  FirebaseTemplateRepository({required this._firestoreService});

  @override
  Stream<List<ExpenseTemplateModel>> getUserTemplates(String userId) {
    return _firestoreService
        .streamDocuments(
          collection: _firestoreService.expenseTemplates,
          queryBuilder: (query) =>
              query.where('userId', isEqualTo: userId).orderBy('createdAt', descending: true),
        )
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                ExpenseTemplateModel.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  @override
  Stream<List<ExpenseTemplateModel>> getTripTemplates(String userId, String tripId) {
    return _firestoreService
        .streamDocuments(
          collection: _firestoreService.expenseTemplates,
          queryBuilder: (query) =>
              query.where('userId', isEqualTo: userId).where('tripId', isEqualTo: tripId).orderBy('createdAt', descending: true),
        )
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                ExpenseTemplateModel.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  @override
  Future<void> addTemplate(ExpenseTemplateModel template) async {
    await _firestoreService.setDocument(
      collection: _firestoreService.expenseTemplates,
      documentId: template.templateId,
      data: template.toJson(),
    );
  }

  @override
  Future<void> updateTemplate(ExpenseTemplateModel template) async {
    await _firestoreService.setDocument(
      collection: _firestoreService.expenseTemplates,
      documentId: template.templateId,
      data: template.toJson(),
      merge: true,
    );
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    await _firestoreService.deleteDocument(
      collection: _firestoreService.expenseTemplates,
      documentId: templateId,
    );
  }

  @override
  Future<void> incrementUsage(String templateId) async {
    await _firestoreService.updateDocument(
      collection: _firestoreService.expenseTemplates,
      documentId: templateId,
      data: {'usageCount': FieldValue.increment(1)},
    );
  }

  @override
  Future<void> toggleFavorite(String templateId, bool favorite) async {
    await _firestoreService.updateDocument(
      collection: _firestoreService.expenseTemplates,
      documentId: templateId,
      data: {'favorite': favorite},
    );
  }
}



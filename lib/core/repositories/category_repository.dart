import '../models/category_model.dart';
import '../services/firestore_service.dart';

abstract class CategoryRepository {
  Stream<List<CategoryModel>> getTripCategories(String tripId);
  Future<void> addCategory(CategoryModel category);
  Future<void> updateCategory(CategoryModel category);
  Future<void> archiveCategory(String categoryId);
  Future<void> deleteCategory(String categoryId);
  Future<void> seedDefaultCategories(List<CategoryModel> categories);
  Future<void> deleteTripCategories(String tripId);
}

class FirebaseCategoryRepository implements CategoryRepository {
  final FirestoreService _firestoreService;

  FirebaseCategoryRepository({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  @override
  Stream<List<CategoryModel>> getTripCategories(String tripId) {
    return _firestoreService
        .streamDocuments(
          collection: _firestoreService.tripCategories,
          queryBuilder: (query) =>
              query.where('tripId', isEqualTo: tripId),
        )
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                CategoryModel.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  @override
  Future<void> addCategory(CategoryModel category) async {
    await _firestoreService.setDocument(
      collection: _firestoreService.tripCategories,
      documentId: category.categoryId,
      data: category.toJson(),
    );
  }

  @override
  Future<void> updateCategory(CategoryModel category) async {
    await _firestoreService.setDocument(
      collection: _firestoreService.tripCategories,
      documentId: category.categoryId,
      data: category.toJson(),
      merge: true,
    );
  }

  @override
  Future<void> archiveCategory(String categoryId) async {
    await _firestoreService.updateDocument(
      collection: _firestoreService.tripCategories,
      documentId: categoryId,
      data: {'isArchived': true},
    );
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    await _firestoreService.deleteDocument(
      collection: _firestoreService.tripCategories,
      documentId: categoryId,
    );
  }

  @override
  Future<void> seedDefaultCategories(List<CategoryModel> categories) async {
    final batch = _firestoreService.batch;
    for (final cat in categories) {
      batch.set(
        _firestoreService.tripCategories.doc(cat.categoryId),
        cat.toJson(),
      );
    }
    await _firestoreService.commitBatch(batch);
  }

  @override
  Future<void> deleteTripCategories(String tripId) async {
    final docs = await _firestoreService.getDocuments(
      collection: _firestoreService.tripCategories,
      queryBuilder: (query) => query.where('tripId', isEqualTo: tripId),
    );
    final batch = _firestoreService.batch;
    for (final doc in docs) {
      batch.delete(doc.reference);
    }
    await _firestoreService.commitBatch(batch);
  }
}



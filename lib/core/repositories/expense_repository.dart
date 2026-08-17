import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_model.dart';
import '../services/firestore_service.dart';
import '../../presentation/providers/firebase_providers.dart';

abstract class ExpenseRepository {
  Stream<List<ExpenseModel>> getTripExpenses(String tripId);

  Future<ExpenseModel> getExpenseById(String expenseId);

  Future<ExpenseModel> addExpense(ExpenseModel expense);

  Future<void> updateExpense(ExpenseModel expense);

  Future<void> deleteExpense(String expenseId);
}

class FirebaseExpenseRepository implements ExpenseRepository {
  final FirestoreService _firestoreService;

  FirebaseExpenseRepository({required this._firestoreService});

  @override
  Stream<List<ExpenseModel>> getTripExpenses(String tripId) {
    return _firestoreService
        .streamDocuments(
          collection: _firestoreService.expenses,
          queryBuilder: (query) =>
              query.where('tripId', isEqualTo: tripId).orderBy('createdAt', descending: true),
        )
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                ExpenseModel.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  @override
  Future<ExpenseModel> getExpenseById(String expenseId) async {
    final doc = await _firestoreService.getDocument(
      collection: _firestoreService.expenses,
      documentId: expenseId,
    );
    return ExpenseModel.fromJson(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<ExpenseModel> addExpense(ExpenseModel expense) async {
    await _firestoreService.setDocument(
      collection: _firestoreService.expenses,
      documentId: expense.expenseId,
      data: expense.toJson(),
    );
    return expense;
  }

  @override
  Future<void> updateExpense(ExpenseModel expense) async {
    await _firestoreService.setDocument(
      collection: _firestoreService.expenses,
      documentId: expense.expenseId,
      data: expense.toJson(),
      merge: true,
    );
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    await _firestoreService.deleteDocument(
      collection: _firestoreService.expenses,
      documentId: expenseId,
    );
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return FirebaseExpenseRepository(firestoreService: firestoreService);
});

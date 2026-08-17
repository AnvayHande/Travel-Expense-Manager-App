import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firebase_constants.dart';
import '../exceptions/app_exceptions.dart';
import '../utils/logger.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService() : _firestore = FirebaseFirestore.instance;

  CollectionReference get users =>
      _firestore.collection(FirebaseConstants.usersCollection);
  CollectionReference get trips =>
      _firestore.collection(FirebaseConstants.tripsCollection);
  CollectionReference get expenses =>
      _firestore.collection(FirebaseConstants.expensesCollection);
  CollectionReference get settlements =>
      _firestore.collection(FirebaseConstants.settlementsCollection);
  CollectionReference get participants =>
      _firestore.collection(FirebaseConstants.participantsCollection);
  CollectionReference get tripActivity =>
      _firestore.collection(FirebaseConstants.tripActivityCollection);
  CollectionReference get tripCategories =>
      _firestore.collection(FirebaseConstants.tripCategoriesCollection);
  CollectionReference get expenseTemplates =>
      _firestore.collection(FirebaseConstants.expenseTemplatesCollection);

  Future<DocumentReference> addDocument({
    required CollectionReference collection,
    required Map<String, dynamic> data,
  }) async {
    try {
      return await collection.add(data);
    } catch (e, stackTrace) {
      AppLogger.error('Firestore addDocument error', e, stackTrace);
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }

  Future<void> setDocument({
    required CollectionReference collection,
    required String documentId,
    required Map<String, dynamic> data,
    bool merge = false,
  }) async {
    try {
      await collection.doc(documentId).set(data, SetOptions(merge: merge));
    } catch (e, stackTrace) {
      AppLogger.error('Firestore setDocument error', e, stackTrace);
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }

  Future<DocumentSnapshot> getDocument({
    required CollectionReference collection,
    required String documentId,
  }) async {
    try {
      final doc = await collection.doc(documentId).get();
      if (!doc.exists) {
        throw const DatabaseException.custom(
          message: 'Document not found.',
          code: 'not-found',
        );
      }
      return doc;
    } catch (e, stackTrace) {
      if (e is DatabaseException) rethrow;
      AppLogger.error('Firestore getDocument error', e, stackTrace);
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }

  Future<List<QueryDocumentSnapshot>> getDocuments({
    required CollectionReference collection,
    Query Function(Query query)? queryBuilder,
  }) async {
    try {
      Query query = collection;
      if (queryBuilder != null) {
        query = queryBuilder(query);
      }
      final snapshot = await query.get();
      return snapshot.docs;
    } catch (e, stackTrace) {
      AppLogger.error('Firestore getDocuments error', e, stackTrace);
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }

  Stream<QuerySnapshot> streamDocuments({
    required CollectionReference collection,
    Query Function(Query query)? queryBuilder,
  }) {
    try {
      Query query = collection;
      if (queryBuilder != null) {
        query = queryBuilder(query);
      }
      return query.snapshots();
    } catch (e, stackTrace) {
      AppLogger.error('Firestore streamDocuments error', e, stackTrace);
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }

  Future<void> updateDocument({
    required CollectionReference collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await collection.doc(documentId).update(data);
    } catch (e, stackTrace) {
      AppLogger.error('Firestore updateDocument error', e, stackTrace);
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }

  Future<void> deleteDocument({
    required CollectionReference collection,
    required String documentId,
  }) async {
    try {
      await collection.doc(documentId).delete();
    } catch (e, stackTrace) {
      AppLogger.error('Firestore deleteDocument error', e, stackTrace);
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }

  WriteBatch get batch => _firestore.batch();

  Future<void> commitBatch(WriteBatch batch) async {
    try {
      await batch.commit();
    } catch (e, stackTrace) {
      AppLogger.error('Firestore commitBatch error', e, stackTrace);
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }

  Future<void> runTransaction(Function(Transaction) handler) async {
    try {
      await _firestore.runTransaction((transaction) async {
        await handler(transaction);
      });
    } catch (e, stackTrace) {
      AppLogger.error('Firestore transaction error', e, stackTrace);
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }
}

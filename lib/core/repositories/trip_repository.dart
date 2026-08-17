import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../exceptions/app_exceptions.dart';
import '../models/trip_model.dart';
import '../models/expense_model.dart';
import '../services/firestore_service.dart';
import '../../presentation/providers/firebase_providers.dart';

abstract class TripRepository {
  Stream<List<TripModel>> getUserTrips(String userId);

  Stream<TripModel?> getTripByIdStream(String tripId);

  Future<TripModel> getTripById(String tripId);

  Future<TripModel?> getTripByInviteCode(String inviteCode);

  Future<TripModel> createTrip(TripModel trip);

  Future<void> updateTrip(TripModel trip);

  Future<void> updateTripStatus(String tripId, String status);

  Future<void> deleteTrip(String tripId);

  Future<void> joinTrip(String tripId, String userId);

  Future<void> leaveTrip(String tripId, String userId);

  Future<String> generateUniqueInviteCode();

  Future<void> removeParticipant(String tripId, String userId);

  Future<void> transferAdminRole(
      String tripId, String newAdminId, String newAdminName);

  Future<void> deleteTripWithAllData(String tripId);

  Future<List<ExpenseModel>> getExpensesForTrip(String tripId);
}

class FirebaseTripRepository implements TripRepository {
  final FirestoreService _firestoreService;

  FirebaseTripRepository({required this._firestoreService});

  static const String _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static const int _codeLength = 6;

  @override
  Stream<List<TripModel>> getUserTrips(String userId) {
    return _firestoreService
        .streamDocuments(
          collection: _firestoreService.trips,
          queryBuilder: (query) =>
              query.where('participants', arrayContains: userId),
        )
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                TripModel.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  @override
  Stream<TripModel?> getTripByIdStream(String tripId) {
    return _firestoreService.trips
        .doc(tripId)
        .snapshots()
        .map((snapshot) =>
            snapshot.exists
                ? TripModel.fromJson(snapshot.data() as Map<String, dynamic>)
                : null);
  }

  @override
  Future<TripModel> getTripById(String tripId) async {
    final doc = await _firestoreService.getDocument(
      collection: _firestoreService.trips,
      documentId: tripId,
    );
    return TripModel.fromJson(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<TripModel?> getTripByInviteCode(String inviteCode) async {
    try {
      final docs = await _firestoreService.getDocuments(
        collection: _firestoreService.trips,
        queryBuilder: (query) =>
            query.where('inviteCode', isEqualTo: inviteCode).limit(1),
      );
      if (docs.isEmpty) return null;
      return TripModel.fromJson(docs.first.data() as Map<String, dynamic>);
    } catch (e) {
      if (e is DatabaseException) rethrow;
      return null;
    }
  }

  @override
  Future<String> generateUniqueInviteCode() async {
    final random = Random();
    String code;
    bool exists;

    do {
      code = List.generate(
        _codeLength,
        (_) => _chars[random.nextInt(_chars.length)],
      ).join();
      final existing = await getTripByInviteCode(code);
      exists = existing != null;
    } while (exists);

    return code;
  }

  @override
  Future<TripModel> createTrip(TripModel trip) async {
    await _firestoreService.setDocument(
      collection: _firestoreService.trips,
      documentId: trip.tripId,
      data: trip.toJson(),
    );
    return trip;
  }

  @override
  Future<void> updateTrip(TripModel trip) async {
    await _firestoreService.setDocument(
      collection: _firestoreService.trips,
      documentId: trip.tripId,
      data: trip.toJson(),
      merge: true,
    );
  }

  @override
  Future<void> updateTripStatus(String tripId, String status) async {
    await _firestoreService.updateDocument(
      collection: _firestoreService.trips,
      documentId: tripId,
      data: {'status': status},
    );
  }

  @override
  Future<void> deleteTrip(String tripId) async {
    await _firestoreService.deleteDocument(
      collection: _firestoreService.trips,
      documentId: tripId,
    );
  }

  @override
  Future<void> joinTrip(String tripId, String userId) async {
    await _firestoreService.runTransaction((transaction) async {
      final docRef = _firestoreService.trips.doc(tripId);
      final doc = await transaction.get(docRef);

      if (!doc.exists) {
        throw const DatabaseException.custom(
          message: 'Trip not found.',
          code: 'not-found',
        );
      }

      final trip = TripModel.fromJson(doc.data() as Map<String, dynamic>);

      if (trip.participants.contains(userId)) {
        throw const DatabaseException.custom(
          message: 'You are already a participant of this trip.',
          code: 'duplicate-participant',
        );
      }

      transaction.update(docRef, {
        'participants': FieldValue.arrayUnion([userId]),
      });
    });
  }

  @override
  Future<void> leaveTrip(String tripId, String userId) async {
    await _firestoreService.updateDocument(
      collection: _firestoreService.trips,
      documentId: tripId,
      data: {
        'participants': FieldValue.arrayRemove([userId]),
      },
    );
  }

  @override
  Future<void> removeParticipant(String tripId, String userId) async {
    await _firestoreService.updateDocument(
      collection: _firestoreService.trips,
      documentId: tripId,
      data: {
        'participants': FieldValue.arrayRemove([userId]),
      },
    );
  }

  @override
  Future<void> transferAdminRole(
      String tripId, String newAdminId, String newAdminName) async {
    await _firestoreService.setDocument(
      collection: _firestoreService.trips,
      documentId: tripId,
      data: {
        'adminId': newAdminId,
        'adminName': newAdminName,
      },
      merge: true,
    );
  }

  @override
  Future<void> deleteTripWithAllData(String tripId) async {
    final expenseDocs = await _firestoreService.getDocuments(
      collection: _firestoreService.expenses,
      queryBuilder: (query) => query.where('tripId', isEqualTo: tripId),
    );
    final settlementDocs = await _firestoreService.getDocuments(
      collection: _firestoreService.settlements,
      queryBuilder: (query) => query.where('tripId', isEqualTo: tripId),
    );
    final activityDocs = await _firestoreService.getDocuments(
      collection: _firestoreService.tripActivity,
      queryBuilder: (query) => query.where('tripId', isEqualTo: tripId),
    );
    final categoryDocs = await _firestoreService.getDocuments(
      collection: _firestoreService.tripCategories,
      queryBuilder: (query) => query.where('tripId', isEqualTo: tripId),
    );

    final batch = _firestoreService.batch;

    for (final doc in expenseDocs) {
      batch.delete(doc.reference);
    }
    for (final doc in settlementDocs) {
      batch.delete(doc.reference);
    }
    for (final doc in activityDocs) {
      batch.delete(doc.reference);
    }
    for (final doc in categoryDocs) {
      batch.delete(doc.reference);
    }

    batch.delete(_firestoreService.trips.doc(tripId));

    await _firestoreService.commitBatch(batch);
  }

  @override
  Future<List<ExpenseModel>> getExpensesForTrip(String tripId) async {
    final docs = await _firestoreService.getDocuments(
      collection: _firestoreService.expenses,
      queryBuilder: (query) => query.where('tripId', isEqualTo: tripId),
    );
    return docs
        .map((doc) => ExpenseModel.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
  }
}

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return FirebaseTripRepository(firestoreService: firestoreService);
});

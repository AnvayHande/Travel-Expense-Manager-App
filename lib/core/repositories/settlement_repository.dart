import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settlement_model.dart';
import '../services/firestore_service.dart';
import '../../presentation/providers/firebase_providers.dart';

abstract class SettlementRepository {
  Stream<List<SettlementModel>> getTripSettlements(String tripId);

  Future<SettlementModel> createSettlement(SettlementModel settlement);

  Future<void> markAsSettled(String settlementId,
      {required String completedBy});

  Future<void> deleteSettlement(String settlementId);
}

class FirebaseSettlementRepository implements SettlementRepository {
  final FirestoreService _firestoreService;

  FirebaseSettlementRepository({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  @override
  Stream<List<SettlementModel>> getTripSettlements(String tripId) {
    return _firestoreService
        .streamDocuments(
          collection: _firestoreService.settlements,
          queryBuilder: (query) =>
              query.where('tripId', isEqualTo: tripId),
        )
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                SettlementModel.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  @override
  Future<SettlementModel> createSettlement(SettlementModel settlement) async {
    await _firestoreService.setDocument(
      collection: _firestoreService.settlements,
      documentId: settlement.settlementId,
      data: settlement.toJson(),
    );
    return settlement;
  }

  @override
  Future<void> markAsSettled(String settlementId,
      {required String completedBy}) async {
    await _firestoreService.updateDocument(
      collection: _firestoreService.settlements,
      documentId: settlementId,
      data: {
        'status': 'completed',
        'completedAt': DateTime.now(),
        'completedBy': completedBy,
      },
    );
  }

  @override
  Future<void> deleteSettlement(String settlementId) async {
    await _firestoreService.deleteDocument(
      collection: _firestoreService.settlements,
      documentId: settlementId,
    );
  }
}

final settlementRepositoryProvider = Provider<SettlementRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return FirebaseSettlementRepository(firestoreService: firestoreService);
});

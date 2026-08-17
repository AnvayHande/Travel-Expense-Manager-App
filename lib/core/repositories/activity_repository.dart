import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_model.dart';
import '../services/firestore_service.dart';
import '../../presentation/providers/firebase_providers.dart';

abstract class ActivityRepository {
  Stream<List<ActivityModel>> getTripActivities(String tripId);

  Future<void> addActivity(ActivityModel activity);
}

class FirebaseActivityRepository implements ActivityRepository {
  final FirestoreService _firestoreService;

  FirebaseActivityRepository({required this._firestoreService});

  @override
  Stream<List<ActivityModel>> getTripActivities(String tripId) {
    return _firestoreService
        .streamDocuments(
          collection: _firestoreService.tripActivity,
          queryBuilder: (query) =>
              query.where('tripId', isEqualTo: tripId).orderBy('createdAt', descending: true),
        )
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                ActivityModel.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  @override
  Future<void> addActivity(ActivityModel activity) async {
    await _firestoreService.setDocument(
      collection: _firestoreService.tripActivity,
      documentId: activity.activityId,
      data: activity.toJson(),
    );
  }
}

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return FirebaseActivityRepository(firestoreService: firestoreService);
});

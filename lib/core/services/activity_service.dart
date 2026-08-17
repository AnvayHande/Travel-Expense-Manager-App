import 'package:uuid/uuid.dart';
import '../models/activity_model.dart';
import '../repositories/activity_repository.dart';

class ActivityService {
  final ActivityRepository _activityRepository;

  ActivityService({required this._activityRepository});

  Future<void> logActivity({
    required String tripId,
    required String userId,
    required String userName,
    required String actionType,
    required String message,
  }) async {
    final activity = ActivityModel(
      activityId: const Uuid().v4(),
      tripId: tripId,
      userId: userId,
      userName: userName,
      actionType: actionType,
      message: message,
      createdAt: DateTime.now(),
    );
    await _activityRepository.addActivity(activity);
  }
}

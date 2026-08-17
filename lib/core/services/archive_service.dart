import '../repositories/trip_repository.dart';
import 'activity_service.dart';

class ArchiveService {
  final TripRepository _tripRepository;
  final ActivityService _activityService;

  ArchiveService({
    required TripRepository tripRepository,
    required ActivityService activityService,
  })  : _tripRepository = tripRepository,
        _activityService = activityService;

  Future<void> closeTrip({
    required String tripId,
    required String tripName,
    required String adminId,
    required String adminName,
  }) async {
    await _tripRepository.updateTripStatus(tripId, 'completed');
    await _activityService.logActivity(
      tripId: tripId,
      userId: adminId,
      userName: adminName,
      actionType: 'trip_closed',
      message: 'closed the trip "$tripName"',
    );
  }

  Future<bool> isTripReadOnly(String tripId) async {
    final trip = await _tripRepository.getTripById(tripId);
    return trip.status == 'completed';
  }
}

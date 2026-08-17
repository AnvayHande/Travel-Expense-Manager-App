import '../exceptions/app_exceptions.dart';
import '../repositories/trip_repository.dart';
import '../services/activity_service.dart';

class TripService {
  final TripRepository _tripRepository;
  final ActivityService _activityService;

  TripService({
    required TripRepository tripRepository,
    required ActivityService activityService,
  })  : _tripRepository = tripRepository,
        _activityService = activityService;

  Future<void> removeParticipant({
    required String tripId,
    required String userIdToRemove,
    required String currentUserId,
    required String currentUserName,
  }) async {
    final expenses = await _tripRepository.getExpensesForTrip(tripId);

    double totalPaid = 0;
    double totalOwed = 0;

    for (final expense in expenses) {
      if (expense.paidBy == userIdToRemove) {
        totalPaid += expense.amount;
      }
      if (expense.splitBetween.contains(userIdToRemove)) {
        totalOwed += expense.splitAmountForUser(userIdToRemove);
      }
    }

    final netBalance = (totalPaid - totalOwed).abs();
    if (netBalance > 0.01) {
      throw const DatabaseException.custom(
        message:
            'Cannot remove participant with a non-zero balance. Settle up first.',
        code: 'non-zero-balance',
      );
    }

    await _tripRepository.removeParticipant(tripId, userIdToRemove);

    if (userIdToRemove != currentUserId) {
      await _activityService.logActivity(
        tripId: tripId,
        userId: currentUserId,
        userName: currentUserName,
        actionType: 'participant_removed',
        message: 'removed a participant from the trip',
      );
    }
  }

  Future<void> transferAdminRole({
    required String tripId,
    required String newAdminId,
    required String newAdminName,
    required String currentUserId,
    required String currentUserName,
  }) async {
    await _tripRepository.transferAdminRole(tripId, newAdminId, newAdminName);

    await _activityService.logActivity(
      tripId: tripId,
      userId: currentUserId,
      userName: currentUserName,
      actionType: 'admin_transferred',
      message: 'transferred admin role to $newAdminName',
    );
  }

  Future<bool> deleteTripWithAllData(String tripId) async {
    try {
      await _tripRepository.deleteTripWithAllData(tripId);
      return true;
    } catch (e) {
      throw DatabaseException.custom(
        message: 'Failed to delete trip: ${e.toString()}',
        code: 'delete-failed',
      );
    }
  }

  Future<void> leaveTrip({
    required String tripId,
    required String userId,
  }) async {
    await _tripRepository.leaveTrip(tripId, userId);
  }
}

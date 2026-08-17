import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/trip_model.dart';
import '../../core/repositories/trip_repository.dart';
import '../../core/services/trip_service.dart';
import '../../core/services/category_service.dart';
import 'authentication_provider.dart';
import 'activity_provider.dart';
import 'category_provider.dart';

final userTripsProvider = StreamProvider<List<TripModel>>((ref) {
  final userId = ref.watch(authProvider).user?.uid;
  if (userId == null) return Stream.value([]);
  final repository = ref.watch(tripRepositoryProvider);
  return repository.getUserTrips(userId);
});

final tripByIdProvider =
    StreamProvider.family<TripModel?, String>((ref, tripId) {
  final repository = ref.watch(tripRepositoryProvider);
  return repository.getTripByIdStream(tripId);
});

class TripState {
  final bool isLoading;
  final String? error;
  final TripModel? pendingTrip;

  const TripState({
    this.isLoading = false,
    this.error,
    this.pendingTrip,
  });

  TripState copyWith({
    bool? isLoading,
    String? error,
    TripModel? pendingTrip,
  }) {
    return TripState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      pendingTrip: pendingTrip ?? this.pendingTrip,
    );
  }
}

class TripNotifier extends StateNotifier<TripState> {
  final TripRepository _tripRepository;
  final TripService _tripService;
  final CategoryService _categoryService;

  TripNotifier(this._tripRepository, this._tripService, this._categoryService)
      : super(const TripState());

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<TripModel?> createTrip({
    required String tripName,
    String? destination,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    required String currency,
    required String adminId,
    required String adminName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final inviteCode = await _tripRepository.generateUniqueInviteCode();
      final tripId = const Uuid().v4();

      final now = DateTime.now();
      final trip = TripModel(
        tripId: tripId,
        tripName: tripName,
        destination: destination,
        description: description,
        startDate: startDate,
        endDate: endDate,
        currency: currency,
        adminId: adminId,
        adminName: adminName,
        inviteCode: inviteCode,
        participants: [adminId],
        createdAt: now,
      );

      await _tripRepository.createTrip(trip);
      await _categoryService.seedDefaults(tripId);
      state = state.copyWith(isLoading: false, pendingTrip: trip);
      return trip;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  Future<bool> updateTrip(TripModel trip) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _tripRepository.updateTrip(trip);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> deleteTrip(String tripId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _tripRepository.deleteTrip(tripId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<TripModel?> getTripByInviteCode(String inviteCode) async {
    try {
      return await _tripRepository.getTripByInviteCode(inviteCode);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> joinTrip(String tripId, String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _tripRepository.joinTrip(tripId, userId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> removeParticipant({
    required String tripId,
    required String userIdToRemove,
    required String currentUserId,
    required String currentUserName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _tripService.removeParticipant(
        tripId: tripId,
        userIdToRemove: userIdToRemove,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> transferAdminRole({
    required String tripId,
    required String newAdminId,
    required String newAdminName,
    required String currentUserId,
    required String currentUserName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _tripService.transferAdminRole(
        tripId: tripId,
        newAdminId: newAdminId,
        newAdminName: newAdminName,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteTripWithAllData(String tripId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _tripService.deleteTripWithAllData(tripId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> leaveTrip({
    required String tripId,
    required String userId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _tripService.leaveTrip(
        tripId: tripId,
        userId: userId,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final tripServiceProvider = Provider<TripService>((ref) {
  final repository = ref.watch(tripRepositoryProvider);
  final activityService = ref.watch(activityServiceProvider);
  return TripService(
    tripRepository: repository,
    activityService: activityService,
  );
});

final tripProvider = StateNotifierProvider<TripNotifier, TripState>((ref) {
  final repository = ref.watch(tripRepositoryProvider);
  final service = ref.watch(tripServiceProvider);
  final categoryService = ref.watch(categoryServiceProvider);
  return TripNotifier(repository, service, categoryService);
});

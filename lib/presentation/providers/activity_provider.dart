import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/activity_model.dart';
import '../../core/repositories/activity_repository.dart';
import '../../core/services/activity_service.dart';

final activityServiceProvider = Provider<ActivityService>((ref) {
  final repository = ref.watch(activityRepositoryProvider);
  return ActivityService(activityRepository: repository);
});

final tripActivitiesProvider =
    StreamProvider.family<List<ActivityModel>, String>((ref, tripId) {
  final repository = ref.watch(activityRepositoryProvider);
  return repository.getTripActivities(tripId);
});

class UnreadState {
  final Map<String, DateTime> lastReadTimestamps;

  const UnreadState({this.lastReadTimestamps = const {}});

  UnreadState copyWith({Map<String, DateTime>? lastReadTimestamps}) {
    return UnreadState(
      lastReadTimestamps: lastReadTimestamps ?? this.lastReadTimestamps,
    );
  }
}

class UnreadNotifier extends StateNotifier<UnreadState> {
  UnreadNotifier() : super(const UnreadState());

  void markAsRead(String tripId) {
    final updated =
        Map<String, DateTime>.from(state.lastReadTimestamps);
    updated[tripId] = DateTime.now();
    state = state.copyWith(lastReadTimestamps: updated);
  }
}

final unreadProvider =
    StateNotifierProvider<UnreadNotifier, UnreadState>((ref) {
  return UnreadNotifier();
});

final unreadActivityCountProvider =
    Provider.family<int, String>((ref, tripId) {
  final activitiesAsync = ref.watch(tripActivitiesProvider(tripId));
  final activities = activitiesAsync.valueOrNull ?? [];
  final unreadState = ref.watch(unreadProvider);
  final lastRead = unreadState.lastReadTimestamps[tripId];

  if (lastRead == null) return activities.length;

  return activities
      .where((a) => a.createdAt.isAfter(lastRead))
      .length;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/firebase_service.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService.instance;
});

final firestoreServiceProvider = Provider((ref) {
  return ref.watch(firebaseServiceProvider).firestore;
});

final authServiceProvider = Provider((ref) {
  return ref.watch(firebaseServiceProvider).auth;
});

final storageServiceProvider = Provider((ref) {
  return ref.watch(firebaseServiceProvider).storage;
});

final userNameProvider = FutureProvider.family<String, String>((ref, uid) async {
  final firestore = ref.watch(firestoreServiceProvider);
  final doc = await firestore.getDocument(
    collection: firestore.users,
    documentId: uid,
  );
  final data = doc.data() as Map<String, dynamic>;
  return data['name'] as String? ?? uid;
});

enum FirebaseInitStatus { initializing, initialized, error }

class FirebaseInitState {
  final FirebaseInitStatus status;
  final String? errorMessage;

  const FirebaseInitState({
    this.status = FirebaseInitStatus.initializing,
    this.errorMessage,
  });

  FirebaseInitState copyWith({
    FirebaseInitStatus? status,
    String? errorMessage,
  }) {
    return FirebaseInitState(
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

class FirebaseInitNotifier extends StateNotifier<FirebaseInitState> {
  FirebaseInitNotifier() : super(const FirebaseInitState());

  Future<void> initialize() async {
    state = const FirebaseInitState(status: FirebaseInitStatus.initializing);
    try {
      await FirebaseService.instance.initialize();
      state = const FirebaseInitState(status: FirebaseInitStatus.initialized);
    } catch (e) {
      state = FirebaseInitState(
        status: FirebaseInitStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}

final firebaseInitProvider =
    StateNotifierProvider<FirebaseInitNotifier, FirebaseInitState>((ref) {
  return FirebaseInitNotifier();
});

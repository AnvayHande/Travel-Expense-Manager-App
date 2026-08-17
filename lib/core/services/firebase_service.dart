import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';
import 'firestore_service.dart';
import 'authentication_service.dart';
import 'storage_service.dart';

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  late final FirebaseApp _app;
  late final FirestoreService _firestoreService;
  late final AuthenticationService _authService;
  late final StorageService _storageService;

  bool _initialized = false;

  bool get isInitialized => _initialized;

  FirebaseApp get app => _app;
  FirestoreService get firestore => _firestoreService;
  AuthenticationService get auth => _authService;
  StorageService get storage => _storageService;

  Future<void> initialize() async {
    if (_initialized) return;

    _app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firestoreService = FirestoreService();
    _authService = AuthenticationService();
    _storageService = StorageService();

    _initialized = true;
  }

  Future<void> reset() async {
    _initialized = false;
  }
}

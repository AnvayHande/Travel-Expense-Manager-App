import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/authentication_service.dart';
import '../services/firestore_service.dart';
import '../../presentation/providers/firebase_providers.dart';

abstract class AuthenticationRepository {
  Stream<UserModel?> get authStateChanges;

  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<UserModel> signUpWithEmailAndPassword({
    required String name,
    required String email,
    required String phone,
    required String password,
  });

  Future<void> signOut();

  Future<UserModel?> getCurrentUser();

  Future<void> resetPassword(String email);
}

class FirebaseAuthenticationRepository implements AuthenticationRepository {
  final AuthenticationService _authService;
  final FirestoreService _firestoreService;

  FirebaseAuthenticationRepository({
    required AuthenticationService authService,
    required FirestoreService firestoreService,
  })  : _authService = authService,
        _firestoreService = firestoreService;

  @override
  Stream<UserModel?> get authStateChanges {
    return _authService.authStateChanges.map((user) {
      if (user == null) return null;
      return UserModel(
        uid: user.uid,
        name: user.displayName ?? '',
        email: user.email ?? '',
        photoUrl: user.photoURL,
        createdAt: user.metadata.creationTime ?? DateTime.now(),
      );
    });
  }

  @override
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final result = await _authService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final firebaseUser = result.user!;

    final now = DateTime.now();
    try {
      await _firestoreService.updateDocument(
        collection: _firestoreService.users,
        documentId: firebaseUser.uid,
        data: {'lastLogin': Timestamp.fromDate(now)},
      );
    } catch (_) {}

    final userModel = await getCurrentUser();
    return userModel ?? UserModel(
      uid: firebaseUser.uid,
      name: firebaseUser.displayName ?? '',
      email: firebaseUser.email ?? '',
      photoUrl: firebaseUser.photoURL,
      createdAt: firebaseUser.metadata.creationTime ?? now,
      lastLogin: now,
    );
  }

  @override
  Future<UserModel> signUpWithEmailAndPassword({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final result = await _authService.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _authService.updateDisplayName(name);

    final user = result.user!;
    final now = DateTime.now();
    final userModel = UserModel(
      uid: user.uid,
      name: name,
      email: email,
      phone: phone,
      photoUrl: '',
      createdAt: now,
      lastLogin: now,
    );

    await _firestoreService.setDocument(
      collection: _firestoreService.users,
      documentId: user.uid,
      data: userModel.toJson(),
    );

    return userModel;
  }

  @override
  Future<void> signOut() async {
    await _authService.signOut();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _authService.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestoreService.getDocument(
        collection: _firestoreService.users,
        documentId: user.uid,
      );
      return UserModel.fromJson(doc.data() as Map<String, dynamic>);
    } catch (_) {
      return UserModel(
        uid: user.uid,
        name: user.displayName ?? '',
        email: user.email ?? '',
        photoUrl: user.photoURL,
        createdAt: user.metadata.creationTime ?? DateTime.now(),
      );
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    await _authService.sendPasswordResetEmail(email: email);
  }
}

final authenticationRepositoryProvider =
    Provider<AuthenticationRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);
  return FirebaseAuthenticationRepository(
    authService: authService,
    firestoreService: firestoreService,
  );
});

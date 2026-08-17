import 'package:firebase_auth/firebase_auth.dart';
import '../exceptions/app_exceptions.dart';

class AuthenticationService {
  final FirebaseAuth _auth;

  AuthenticationService() : _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e, stackTrace) {
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e, stackTrace) {
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e, stackTrace) {
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e, stackTrace) {
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
      await _auth.currentUser?.reload();
    } catch (e, stackTrace) {
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }
}

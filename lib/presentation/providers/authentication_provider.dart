import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../../core/models/user_model.dart';
import '../../core/repositories/authentication_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? error,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthenticationRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AuthState()) {
    _init();
  }

  void _init() {
    _authRepository.authStateChanges.listen((user) {
      if (user != null && state.status != AuthStatus.authenticated) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
      } else if (user == null && state.status != AuthStatus.unauthenticated) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  Future<bool> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );
      return true;
    } catch (e) {
      final message = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        isLoading: false,
        error: message,
      );
      return false;
    }
  }

  Future<bool> signUpWithEmailAndPassword({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authRepository.signUpWithEmailAndPassword(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );
      return true;
    } catch (e) {
      final message = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        isLoading: false,
        error: message,
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _authRepository.resetPassword(email);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authenticationRepositoryProvider);
  return AuthNotifier(repository);
});

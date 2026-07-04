import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../data/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthController extends StateNotifier<AppAuthState> {
  AuthController(this._repository) : super(const AppAuthState.loading()) {
    _initialize();
    _subscription = _repository.authStateChanges.listen((event) {
      if (event.session == null) {
        state = const AppAuthState.unauthenticated();
      }
    });
  }

  final AuthRepository _repository;
  StreamSubscription<dynamic>? _subscription;

  Future<void> _initialize() async {
    try {
      final profile = await _repository.getCurrentProfile();

      state = profile == null
          ? const AppAuthState.unauthenticated()
          : AppAuthState.authenticated(profile);
    } on AppException catch (error) {
      state = AppAuthState.unauthenticated(errorMessage: error.message);
    } catch (_) {
      state = const AppAuthState.unauthenticated(
        errorMessage: 'Unable to restore your session.',
      );
    }
  }

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    state = const AppAuthState.loading();

    try {
      final profile = await _repository.signInWithUsername(
        username: username,
        password: password,
      );

      state = AppAuthState.authenticated(profile);
    } on AppException catch (error) {
      state = AppAuthState.unauthenticated(errorMessage: error.message);
    } catch (_) {
      state = const AppAuthState.unauthenticated(
        errorMessage: 'Unable to sign in. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    state = const AppAuthState.loading();
    await _repository.signOut();
    state = const AppAuthState.unauthenticated();
  }

  Future<void> sendPasswordResetEmail(String username) async {
    state = const AppAuthState.loading();

    try {
      await _repository.sendPasswordResetEmail(username);
      state = const AppAuthState.unauthenticated(
        successMessage: 'Password reset email sent.',
      );
    } on AppException catch (error) {
      state = AppAuthState.unauthenticated(errorMessage: error.message);
    } catch (_) {
      state = const AppAuthState.unauthenticated(
        errorMessage: 'Unable to send password reset email.',
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AppAuthState>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);

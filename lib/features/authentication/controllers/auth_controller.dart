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
  final Map<String, _AttemptBucket> _attemptBuckets = {};
  final Map<String, _AttemptBucket> _resetBuckets = {};

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
    final limitMessage = _checkLocalLimit(
      buckets: _attemptBuckets,
      key: username.trim().toLowerCase(),
      limit: 5,
      window: const Duration(minutes: 15),
      actionLabel: 'login attempts',
    );

    if (limitMessage != null) {
      state = AppAuthState.unauthenticated(errorMessage: limitMessage);
      return;
    }

    state = const AppAuthState.loading();

    try {
      final profile = await _repository.signInWithUsername(
        username: username,
        password: password,
      );

      _attemptBuckets.remove(username.trim().toLowerCase());
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
    final limitMessage = _checkLocalLimit(
      buckets: _resetBuckets,
      key: username.trim().toLowerCase(),
      limit: 3,
      window: const Duration(minutes: 15),
      actionLabel: 'password reset requests',
    );

    if (limitMessage != null) {
      state = AppAuthState.unauthenticated(errorMessage: limitMessage);
      return;
    }

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

String? _checkLocalLimit({
  required Map<String, _AttemptBucket> buckets,
  required String key,
  required int limit,
  required Duration window,
  required String actionLabel,
}) {
  final normalizedKey = key.isEmpty ? 'anonymous' : key;
  final now = DateTime.now();
  final existing = buckets[normalizedKey];

  if (existing == null || now.isAfter(existing.resetAt)) {
    buckets[normalizedKey] = _AttemptBucket(
      count: 1,
      resetAt: now.add(window),
    );
    return null;
  }

  if (existing.count >= limit) {
    final remaining = existing.resetAt.difference(now);
    final minutes = remaining.inMinutes <= 0 ? 1 : remaining.inMinutes + 1;

    return 'Too many $actionLabel. Please wait $minutes minute${minutes == 1 ? '' : 's'} before trying again.';
  }

  buckets[normalizedKey] = existing.copyWith(count: existing.count + 1);
  return null;
}

class _AttemptBucket {
  const _AttemptBucket({
    required this.count,
    required this.resetAt,
  });

  final int count;
  final DateTime resetAt;

  _AttemptBucket copyWith({int? count, DateTime? resetAt}) {
    return _AttemptBucket(
      count: count ?? this.count,
      resetAt: resetAt ?? this.resetAt,
    );
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AppAuthState>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);

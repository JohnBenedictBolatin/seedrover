import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/features/authentication/controllers/auth_state.dart';

void main() {
  test('unauthenticated state is stable', () {
    const state = AppAuthState.unauthenticated();
    expect(state.isLoading, isFalse);
    expect(state.isAuthenticated, isFalse);
    expect(state.profile, isNull);
  });
}

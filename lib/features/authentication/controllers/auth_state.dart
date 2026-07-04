import '../data/models/auth_profile_model.dart';

class AppAuthState {
  const AppAuthState({
    required this.isLoading,
    this.profile,
    this.errorMessage,
    this.successMessage,
  });

  const AppAuthState.loading()
      : isLoading = true,
        profile = null,
        errorMessage = null,
        successMessage = null;

  const AppAuthState.unauthenticated({
    this.errorMessage,
    this.successMessage,
  })
      : isLoading = false,
        profile = null;

  const AppAuthState.authenticated(this.profile)
      : isLoading = false,
        errorMessage = null,
        successMessage = null;

  final bool isLoading;
  final AuthProfileModel? profile;
  final String? errorMessage;
  final String? successMessage;

  bool get isAuthenticated => profile != null;
}

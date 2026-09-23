import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../providers/auth_providers.dart';

const _loginIllustrationHeight = 280.0;
const _loginPanelTop = 200.0;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _rememberUsernameKey = 'seedrover.remember_username';
  static const _rememberEnabledKey = 'seedrover.remember_enabled';

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _restoreRememberedUsername();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await ref.read(authControllerProvider.notifier).signIn(
          username: _usernameController.text,
          password: _passwordController.text,
        );

    if (ref.read(authControllerProvider).isAuthenticated) {
      await _saveRememberPreference();
    }
  }

  Future<void> _restoreRememberedUsername() async {
    final preferences = await SharedPreferences.getInstance();
    final shouldRemember = preferences.getBool(_rememberEnabledKey) ?? false;
    final rememberedUsername = preferences.getString(_rememberUsernameKey);

    if (!mounted || !shouldRemember || rememberedUsername == null) {
      return;
    }

    setState(() {
      _rememberMe = true;
      _usernameController.text = rememberedUsername;
    });
  }

  Future<void> _saveRememberPreference() async {
    final preferences = await SharedPreferences.getInstance();

    if (_rememberMe) {
      await preferences.setBool(_rememberEnabledKey, true);
      await preferences.setString(
        _rememberUsernameKey,
        _usernameController.text.trim(),
      );
      return;
    }

    await preferences.setBool(_rememberEnabledKey, false);
    await preferences.remove(_rememberUsernameKey);
    _usernameController.clear();
  }

  Future<void> _setRememberMe(bool value) async {
    setState(() => _rememberMe = value);

    if (value) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_rememberEnabledKey, false);
    await preferences.remove(_rememberUsernameKey);
  }

  Future<void> _sendPasswordResetEmail() async {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your username first.')),
      );
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .sendPasswordResetEmail(username);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryBackground,
                AppColors.secondaryBackground,
                AppColors.primaryBackground,
              ],
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _LoginIllustrationPlaceholder(),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.only(
                  top: _loginPanelTop,
                  bottom: AppSpacing.lg,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 430,
                      minHeight: MediaQuery.sizeOf(context).height >
                              _loginPanelTop
                          ? MediaQuery.sizeOf(context).height - _loginPanelTop
                          : 0,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground.withValues(
                          alpha: 0.96,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(36),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.xl,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Image.asset(
                                  'assets/images/SeedRover Logo Light.png',
                                  width: 226,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Welcome back!',
                                textAlign: TextAlign.center,
                                style: AppTypography.sectionHeading.copyWith(
                                  color: AppColors.primaryText,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Your planting tools are set, and the fields are waiting.',
                                textAlign: TextAlign.center,
                                style: AppTypography.body.copyWith(
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _usernameController,
                                      enabled: !authState.isLoading,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'Username',
                                        prefixIcon: Icon(Icons.person_outline),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Enter your username.';
                                        }

                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    TextFormField(
                                      controller: _passwordController,
                                      enabled: !authState.isLoading,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _submit(),
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon:
                                            const Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                          tooltip: _obscurePassword
                                              ? 'Show password'
                                              : 'Hide password',
                                          onPressed: authState.isLoading
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _obscurePassword =
                                                        !_obscurePassword;
                                                  });
                                                },
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Enter your password.';
                                        }

                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    _RememberMeRow(
                                      value: _rememberMe,
                                      enabled: !authState.isLoading,
                                      onChanged: (value) {
                                        _setRememberMe(value);
                                      },
                                      onForgotPassword: _sendPasswordResetEmail,
                                    ),
                                    if (authState.errorMessage != null) ...[
                                      const SizedBox(height: AppSpacing.md),
                                      _LoginMessage(
                                        message: authState.errorMessage!,
                                        color: AppColors.danger,
                                      ),
                                    ],
                                    if (authState.successMessage != null) ...[
                                      const SizedBox(height: AppSpacing.md),
                                      _LoginMessage(
                                        message: authState.successMessage!,
                                        color: AppColors.success,
                                      ),
                                    ],
                                    const SizedBox(height: AppSpacing.lg),
                                    PrimaryButton(
                                      label: 'LOG IN',
                                      isLoading: authState.isLoading,
                                      onPressed: _submit,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Text(
                                'Version ${AppConstants.appVersion}',
                                textAlign: TextAlign.center,
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginIllustrationPlaceholder extends StatelessWidget {
  const _LoginIllustrationPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _loginIllustrationHeight,
      width: double.infinity,
      child: Image.asset(
        'assets/images/illustration_mobile.png',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _RememberMeRow extends StatelessWidget {
  const _RememberMeRow({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onForgotPassword,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          height: 30,
          width: 30,
          child: Checkbox(
            value: value,
            activeColor: AppColors.primaryGreen,
            checkColor: AppColors.primaryBackground,
            side: BorderSide(color: AppColors.primaryGreen),
            onChanged:
                enabled ? (nextValue) => onChanged(nextValue ?? false) : null,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: GestureDetector(
            onTap: enabled ? () => onChanged(!value) : null,
            child: Text(
              'Remember me',
              style: AppTypography.small.copyWith(
                color: AppColors.secondaryText,
                fontSize: 11,
                height: 14 / 11,
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: enabled ? onForgotPassword : null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: AppTypography.small.copyWith(
              fontSize: 11,
              height: 14 / 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Forgot password?'),
        ),
      ],
    );
  }
}

class _LoginMessage extends StatelessWidget {
  const _LoginMessage({
    required this.message,
    required this.color,
  });

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          message,
          style: AppTypography.small.copyWith(color: AppColors.primaryText),
        ),
      ),
    );
  }
}

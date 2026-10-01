import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/config/app_environment.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/seedrover_mascot.dart';
import '../../providers/auth_providers.dart';

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

  Future<void> _openPasswordRecoveryWebsite() async {
    final configuredOrigin = ref.read(appEnvironmentProvider).webAdminUrl;
    final origin = Uri.tryParse(configuredOrigin);
    if (origin == null ||
        !origin.hasAuthority ||
        origin.host.isEmpty ||
        !const {'http', 'https'}.contains(origin.scheme) ||
        origin.userInfo.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password recovery website is not configured.'),
        ),
      );
      return;
    }

    final loginUri = origin.replace(
      path: '/login',
      queryParameters: const {'reset': '1'},
    );
    try {
      final opened = await launchUrl(
        loginUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened || !mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the SeedRover recovery website.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the SeedRover recovery website.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 80;

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          if (!keyboardOpen && MediaQuery.sizeOf(context).height > 700)
            Positioned(
              left: 0,
              right: 0,
              bottom: -120,
              child: const IgnorePointer(
                child: Center(
                  child: SeedRoverMascot(
                    expression: SeedRoverMascotExpression.happy,
                    size: 240,
                  ),
                ),
              ),
            ),
          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _LoginHero(compact: keyboardOpen),
                ),
                SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    keyboardOpen ? 84 : 144,
                    AppSpacing.md,
                    keyboardOpen ? AppSpacing.lg : 132,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBackground,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.inactiveBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .08),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Welcome back',
                                      style: AppTypography.sectionHeading),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Sign in to your SeedRover workspace.',
                                  style: AppTypography.small.copyWith(
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
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
                                        autofillHints: const [
                                          AutofillHints.username
                                        ],
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                          labelText: 'Username',
                                          prefixIcon:
                                              Icon(Icons.person_outline),
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
                                        autofillHints: const [
                                          AutofillHints.password
                                        ],
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
                                                  : Icons
                                                      .visibility_off_outlined,
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
                                      const SizedBox(height: AppSpacing.smd),
                                      _RememberMeRow(
                                        value: _rememberMe,
                                        enabled: !authState.isLoading,
                                        onChanged: (value) {
                                          _setRememberMe(value);
                                        },
                                        onForgotPassword:
                                            _openPasswordRecoveryWebsite,
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
                                const SizedBox(height: AppSpacing.lg),
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
        ],
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        height: compact ? 96 : 158,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.heroGradientColors,
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(32),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -52,
              top: compact ? -82 : -96,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .10),
                    width: 24,
                  ),
                ),
              ),
            ),
            Positioned(
              right: compact ? 24 : 48,
              bottom: compact ? -72 : -88,
              child: Icon(
                Icons.eco_rounded,
                size: compact ? 164 : 220,
                color: Colors.white.withValues(alpha: .06),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: compact ? 12 : 30),
              child: Align(
                alignment: Alignment.topCenter,
                child: Semantics(
                  image: true,
                  label: 'SeedRover',
                  child: Image.asset(
                    'assets/images/SeedRover Logo White Mobile.png',
                    width: compact ? 150 : 190,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
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
              'Remember username',
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
        color: color.withValues(alpha: 0.12),
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

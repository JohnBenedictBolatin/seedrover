import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  AnimationController? _fieldAnimationController;

  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _fieldAnimationController = _createFieldAnimationController();
  }

  @override
  void dispose() {
    _fieldAnimationController?.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  AnimationController get _fieldAnimation {
    return _fieldAnimationController ??= _createFieldAnimationController();
  }

  AnimationController _createFieldAnimationController() {
    return AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await ref.read(authControllerProvider.notifier).signIn(
          username: _usernameController.text,
          password: _passwordController.text,
        );
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
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: Stack(
        children: [
          SafeArea(
            child: DecoratedBox(
              decoration: const BoxDecoration(
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
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    112,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Image.asset(
                              'assets/images/SeedRover Logo.png',
                              width: 226,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Welcome back, field operator.',
                            textAlign: TextAlign.center,
                            style: AppTypography.sectionHeading.copyWith(
                              color: AppColors.primaryText,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Your rover dashboard is warmed up and waiting for you.',
                            textAlign: TextAlign.center,
                            style: AppTypography.body.copyWith(
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.secondaryBackground.withOpacity(
                                0.88,
                              ),
                              border: Border.all(
                                color: AppColors.inactiveBorder,
                              ),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                      setState(() => _rememberMe = value);
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
          if (!keyboardVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: _PixelFarmRunner(animation: _fieldAnimation),
              ),
            ),
        ],
      ),
    );
  }
}

class _PixelFarmRunner extends StatelessWidget {
  const _PixelFarmRunner({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          return SizedBox(
            height: 96,
            width: double.infinity,
            child: CustomPaint(
              painter: _PixelFarmPainter(progress: animation.value),
            ),
          );
        },
      ),
    );
  }
}

class _PixelFarmPainter extends CustomPainter {
  const _PixelFarmPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final pixel = (size.width / 88).clamp(5.0, 9.0).toDouble();
    final baseline = size.height - pixel * 2;
    final primary = Paint()..color = AppColors.primaryGreen;
    final accent = Paint()..color = AppColors.accentGreen;
    final dark = Paint()..color = AppColors.darkGradientStart;
    final shadow = Paint()..color = AppColors.primaryGreen.withOpacity(0.18);

    canvas.drawRect(
      Rect.fromLTWH(0, baseline, size.width, pixel),
      primary,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, baseline + pixel, size.width, pixel),
      shadow,
    );

    final offset = progress * pixel * 18;
    final repeat = pixel * 18;
    final count = (size.width / repeat).ceil() + 3;

    for (var index = -1; index < count; index++) {
      final start = index * repeat - offset % repeat;
      _drawGrassCluster(canvas, start, baseline, pixel, primary, accent);

      if (index.isEven) {
        _drawTree(canvas, start + pixel * 10, baseline, pixel, primary, dark);
      } else {
        _drawSapling(canvas, start + pixel * 8, baseline, pixel, accent);
      }
    }
  }

  void _drawGrassCluster(
    Canvas canvas,
    double x,
    double baseline,
    double pixel,
    Paint primary,
    Paint accent,
  ) {
    canvas.drawRect(Rect.fromLTWH(x, baseline - pixel, pixel, pixel), primary);
    canvas.drawRect(
      Rect.fromLTWH(x + pixel * 2, baseline - pixel * 3, pixel, pixel * 3),
      accent,
    );
    canvas.drawRect(
      Rect.fromLTWH(x + pixel * 4, baseline - pixel, pixel, pixel),
      primary,
    );
    canvas.drawRect(
      Rect.fromLTWH(x + pixel * 6, baseline - pixel * 2.5, pixel, pixel * 2.5),
      accent,
    );
  }

  void _drawTree(
    Canvas canvas,
    double x,
    double baseline,
    double pixel,
    Paint leaf,
    Paint trunk,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(x + pixel * 2, baseline - pixel * 5, pixel, pixel * 5),
      trunk,
    );
    canvas.drawRect(
      Rect.fromLTWH(x, baseline - pixel * 9, pixel * 5, pixel),
      leaf,
    );
    canvas.drawRect(
      Rect.fromLTWH(x + pixel, baseline - pixel * 10, pixel * 3, pixel),
      leaf,
    );
    canvas.drawRect(
      Rect.fromLTWH(x + pixel * 2, baseline - pixel * 11, pixel, pixel),
      leaf,
    );
    canvas.drawRect(
      Rect.fromLTWH(x + pixel, baseline - pixel * 8, pixel * 3, pixel),
      leaf,
    );
  }

  void _drawSapling(
    Canvas canvas,
    double x,
    double baseline,
    double pixel,
    Paint paint,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(x + pixel, baseline - pixel * 5, pixel, pixel * 5),
      paint,
    );
    canvas.drawRect(Rect.fromLTWH(x, baseline - pixel * 4, pixel, pixel), paint);
    canvas.drawRect(
      Rect.fromLTWH(x + pixel * 2, baseline - pixel * 6, pixel, pixel),
      paint,
    );
  }

  @override
  bool shouldRepaint(_PixelFarmPainter oldDelegate) {
    return oldDelegate.progress != progress;
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
          height: 34,
          width: 34,
          child: Checkbox(
            value: value,
            activeColor: AppColors.primaryGreen,
            checkColor: AppColors.primaryBackground,
            side: const BorderSide(color: AppColors.primaryGreen),
            onChanged: enabled
                ? (nextValue) => onChanged(nextValue ?? false)
                : null,
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
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: enabled ? onForgotPassword : null,
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

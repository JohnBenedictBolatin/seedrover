import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import '../theme/theme_mode_controller.dart';
import 'app_router.dart';

class SeedRoverApp extends ConsumerWidget {
  const SeedRoverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final lightTheme = AppTheme.light;
    final darkTheme = AppTheme.dark;
    AppColors.useLightPalette(themeMode == ThemeMode.light);

    return MaterialApp.router(
      title: 'SeedRover',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return _SeedRoverStartupSplash(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _SeedRoverStartupSplash extends StatefulWidget {
  const _SeedRoverStartupSplash({required this.child});

  final Widget child;

  @override
  State<_SeedRoverStartupSplash> createState() =>
      _SeedRoverStartupSplashState();
}

class _SeedRoverStartupSplashState extends State<_SeedRoverStartupSplash>
    with SingleTickerProviderStateMixin {
  static const _messages = [
    'Firing up the rover...',
    'Retrieving inventory data...',
    'Checking crop records...',
    'Syncing field systems...',
  ];

  late final AnimationController _progressController;
  var _messageIndex = 0;
  var _showSplash = true;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _cycleMessages();
    _dismissSplash();
  }

  Future<void> _cycleMessages() async {
    for (var index = 1; index < _messages.length; index++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) {
        return;
      }
      setState(() => _messageIndex = index);
    }
  }

  Future<void> _dismissSplash() async {
    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (!mounted) {
      return;
    }
    setState(() => _showSplash = false);
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !_showSplash,
          child: AnimatedOpacity(
            opacity: _showSplash ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: Material(
              color: AppColors.primaryBackground,
              child: DefaultTextStyle(
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryText,
                  decoration: TextDecoration.none,
                ),
                child: Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/seedrover_splash.png',
                          width: 172,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        SizedBox(
                          width: 280,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: Text(
                              _messages[_messageIndex],
                              key: ValueKey(_messages[_messageIndex]),
                              textAlign: TextAlign.center,
                              style: AppTypography.body.copyWith(
                                color: AppColors.secondaryText,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: 240,
                          child: AnimatedBuilder(
                            animation: _progressController,
                            builder: (context, _) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 6,
                                  backgroundColor: AppColors.cardBackground,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryGreen,
                                  ),
                                  value: _progressController.value,
                                ),
                              );
                            },
                          ),
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
    );
  }
}

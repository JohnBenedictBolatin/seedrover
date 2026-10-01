import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Dashboard-style full-width gradient backdrop with its content layered above.
class WelcomeHeaderBackdrop extends StatelessWidget {
  const WelcomeHeaderBackdrop({
    required this.header,
    required this.briefing,
    super.key,
  });

  final Widget header;
  final Widget briefing;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _WelcomeBackdropPainter(
                colors: AppColors.heroGradientColors,
                topInset: AppSpacing.lg,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                header,
                const SizedBox(height: AppSpacing.lg),
                briefing,
              ],
            ),
          ),
        ],
      );
}

class _WelcomeBackdropPainter extends CustomPainter {
  const _WelcomeBackdropPainter({required this.colors, required this.topInset});

  final List<Color> colors;
  final double topInset;

  @override
  void paint(Canvas canvas, Size size) {
    final edge = topInset + (size.height - topInset) * .76;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, edge - 18)
      ..quadraticBezierTo(size.width * .52, edge + 12, 0, edge - 8)
      ..close();
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WelcomeBackdropPainter oldDelegate) =>
      oldDelegate.colors[0] != colors[0] ||
      oldDelegate.colors[1] != colors[1] ||
      oldDelegate.topInset != topInset;
}

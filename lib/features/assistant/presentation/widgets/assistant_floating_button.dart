import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/seedrover_mascot.dart';
import '../../providers/assistant_providers.dart';
import 'assistant_chat_sheet.dart';

class AssistantFloatingButton extends ConsumerWidget {
  const AssistantFloatingButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assistantControllerProvider);

    return Tooltip(
      message: 'Ask Rovie',
      child: GestureDetector(
        onTap: state.isOpen
            ? null
            : () {
                ref.read(assistantControllerProvider.notifier).open();
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const AssistantChatSheet(),
                ).whenComplete(
                  () => ref.read(assistantControllerProvider.notifier).close(),
                );
              },
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.bottomCenter,
              radius: 1.25,
              colors: AppColors.heroGradientColors,
            ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.primaryGreen.withOpacity(.34)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withOpacity(.10),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _AskButtonStarFieldPainter()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SeedRoverMascot(
                      expression: SeedRoverMascotExpression.assistant,
                      size: 38,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      CupertinoIcons.chat_bubble_text,
                      color: AppColors.heroPrimaryText,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Ask',
                      style: AppTypography.statusBadge.copyWith(
                        color: AppColors.heroPrimaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AskButtonStarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const stars = <Offset>[
      Offset(.08, .22),
      Offset(.18, .58),
      Offset(.32, .28),
      Offset(.48, .70),
      Offset(.62, .22),
      Offset(.78, .54),
      Offset(.90, .30),
    ];
    final paint = Paint()..color = AppColors.accentGreen.withOpacity(.42);
    for (var index = 0; index < stars.length; index++) {
      final star = stars[index];
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        index.isEven ? 1.05 : .65,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

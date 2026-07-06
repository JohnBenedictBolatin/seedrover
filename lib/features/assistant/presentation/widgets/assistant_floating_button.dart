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
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.buttonGradientStart,
                AppColors.buttonGradientEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Padding(
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
                  color: AppColors.primaryText,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Ask',
                  style: AppTypography.statusBadge.copyWith(
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

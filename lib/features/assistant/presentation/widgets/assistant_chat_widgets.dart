import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/seedrover_mascot.dart';
import '../../data/models/assistant_message_model.dart';

class AssistantHeader extends StatelessWidget {
  const AssistantHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const SeedRoverMascot(
            expression: SeedRoverMascotExpression.assistant,
            size: 52,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rovie', style: AppTypography.cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Ask about SeedRover, crops, stocks, or planting.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close assistant',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(CupertinoIcons.xmark, color: AppColors.primaryText),
          ),
        ],
      ),
    );
  }
}

class AssistantBubble extends StatelessWidget {
  const AssistantBubble({required this.message, super.key});

  final AssistantMessageModel message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AssistantMessageRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isUser
                ? AppColors.cardBackground
                : AppColors.primaryBackground,
            border: Border.all(
              color: isUser ? AppColors.primaryGreen : AppColors.inactiveBorder,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              message.content,
              style: AppTypography.small.copyWith(
                color: AppColors.primaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AssistantSuggestionRow extends StatelessWidget {
  const AssistantSuggestionRow({
    required this.suggestions,
    required this.onTap,
    super.key,
  });

  final List<String> suggestions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final suggestion in suggestions)
            OutlinedButton(
              onPressed: () => onTap(suggestion),
              child: Text(suggestion),
            ),
        ],
      ),
    );
  }
}

class AssistantNotice extends StatelessWidget {
  const AssistantNotice({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTypography.caption.copyWith(color: AppColors.warning),
      ),
    );
  }
}

class AssistantInput extends StatelessWidget {
  const AssistantInput({
    required this.controller,
    required this.enabled,
    required this.isSending,
    required this.onSubmit,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isSending;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: onSubmit,
              decoration: const InputDecoration(
                hintText: 'Ask Rovie...',
                prefixIcon: Icon(CupertinoIcons.sparkles),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Send',
            onPressed: enabled ? () => onSubmit(controller.text) : null,
            icon: isSending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    CupertinoIcons.arrow_up_circle_fill,
                    color: AppColors.primaryGreen,
                  ),
          ),
        ],
      ),
    );
  }
}

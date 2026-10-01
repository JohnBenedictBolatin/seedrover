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
                  'Ask about SeedRover, crops, inventory, or planting.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close assistant',
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(CupertinoIcons.xmark, color: AppColors.primaryText),
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
            child: _AssistantRichText(message.content),
          ),
        ),
      ),
    );
  }
}

class _AssistantRichText extends StatelessWidget {
  const _AssistantRichText(this.content);

  final String content;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.small.copyWith(color: AppColors.primaryText);
    final spans = <InlineSpan>[];
    final boldPattern = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
    var cursor = 0;

    for (final match in boldPattern.allMatches(content)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: content.substring(cursor, match.start)));
      }

      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      cursor = match.end;
    }

    if (cursor < content.length) {
      spans.add(TextSpan(text: content.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: style, children: spans),
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
  const AssistantNotice({this.message, this.onRetry, super.key});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (message != null)
          Text(
            message!,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: AppColors.warning),
          ),
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry message'),
          ),
      ]),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        minLines: 1,
        maxLines: 3,
        textInputAction: TextInputAction.send,
        onSubmitted: onSubmit,
        decoration: InputDecoration(
          hintText: 'Ask Rovie...',
          prefixIcon: const Icon(CupertinoIcons.sparkles),
          suffixIconConstraints: const BoxConstraints.tightFor(
            width: 48,
            height: 48,
          ),
          suffixIcon: IconButton(
            tooltip: 'Send',
            padding: EdgeInsets.zero,
            onPressed: enabled ? () => onSubmit(controller.text) : null,
            icon: isSending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    CupertinoIcons.arrow_up_circle_fill,
                    color: Colors.white,
                  ),
          ),
        ),
      ),
    );
  }
}

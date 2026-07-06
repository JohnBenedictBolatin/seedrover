import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../providers/assistant_providers.dart';
import 'assistant_chat_widgets.dart';

class AssistantChatSheet extends ConsumerStatefulWidget {
  const AssistantChatSheet({super.key});

  @override
  ConsumerState<AssistantChatSheet> createState() => _AssistantChatSheetState();
}

class _AssistantChatSheetState extends ConsumerState<AssistantChatSheet> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  static const _suggestions = [
    'How do I start planting?',
    'Is my soil good for sitaw?',
    'Why is rover control locked?',
    'How should I track harvested produce?',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String message) async {
    await ref.read(assistantControllerProvider.notifier).sendMessage(message);
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantControllerProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    ref.listen(assistantControllerProvider, (previous, next) {
      if (next.messages.length != previous?.messages.length) {
        _scrollToBottom();
      }
    });

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: bottomInset + AppSpacing.md,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          border: Border.all(color: AppColors.inactiveBorder),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          child: Column(
            children: [
              const AssistantHeader(),
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemBuilder: (context, index) {
                    return AssistantBubble(message: state.messages[index]);
                  },
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemCount: state.messages.length,
                ),
              ),
              if (state.errorMessage != null)
                AssistantNotice(message: state.errorMessage!),
              if (state.messages.length == 1)
                AssistantSuggestionRow(
                  suggestions: _suggestions,
                  onTap: _send,
                ),
              AssistantInput(
                controller: _messageController,
                enabled: !state.isSending,
                isSending: state.isSending,
                onSubmit: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

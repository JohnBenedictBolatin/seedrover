import '../data/models/assistant_message_model.dart';

class AssistantState {
  const AssistantState({
    required this.messages,
    this.isOpen = false,
    this.isSending = false,
    this.errorMessage,
  });

  factory AssistantState.initial() {
    return AssistantState(
      messages: [
        AssistantMessageModel(
          id: 'assistant-welcome',
          role: AssistantMessageRole.assistant,
          content:
              'Hi, I\'m Rovie. I can help with SeedRover workflows, current app crop/stock data, rover basics, planting, and farm-care questions.',
          createdAt: DateTime.now(),
        ),
      ],
    );
  }

  final List<AssistantMessageModel> messages;
  final bool isOpen;
  final bool isSending;
  final String? errorMessage;

  AssistantState copyWith({
    List<AssistantMessageModel>? messages,
    bool? isOpen,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      isOpen: isOpen ?? this.isOpen,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

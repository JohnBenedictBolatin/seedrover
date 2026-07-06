import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/assistant_context_model.dart';
import '../data/models/assistant_message_model.dart';
import '../data/repositories/assistant_repository.dart';
import 'assistant_state.dart';

class AssistantController extends StateNotifier<AssistantState> {
  AssistantController(
    this._repository, {
    required AssistantContextModel Function() readContext,
  })  : _readContext = readContext,
        super(AssistantState.initial());

  final AssistantRepository _repository;
  final AssistantContextModel Function() _readContext;

  void open() {
    state = state.copyWith(isOpen: true, clearError: true);
  }

  void close() {
    state = state.copyWith(isOpen: false, clearError: true);
  }

  Future<void> sendMessage(String rawQuestion) async {
    final question = rawQuestion.trim();

    if (question.isEmpty || state.isSending) {
      return;
    }

    final userMessage = _message(
      role: AssistantMessageRole.user,
      content: question,
    );
    final nextMessages = [...state.messages, userMessage];

    state = state.copyWith(
      messages: nextMessages,
      isSending: true,
      clearError: true,
    );

    try {
      final answer = await _repository.ask(
        question: question,
        history: nextMessages,
        context: _readAssistantContext(),
      );

      state = state.copyWith(
        messages: [
          ...nextMessages,
          _message(role: AssistantMessageRole.assistant, content: answer),
        ],
        isSending: false,
      );
    } catch (error) {
      final detail = error is AssistantException
          ? error.message
          : 'Unexpected assistant error: $error';

      state = state.copyWith(
        messages: [
          ...nextMessages,
          _message(
            role: AssistantMessageRole.assistant,
            content: '${_fallbackAnswer(question)}\n\nConnection detail: $detail',
          ),
        ],
        isSending: false,
        errorMessage: 'Using local fallback. Detail: $detail',
      );
    }
  }

  AssistantMessageModel _message({
    required AssistantMessageRole role,
    required String content,
  }) {
    final timestamp = DateTime.now();

    return AssistantMessageModel(
      id: '${role.apiValue}-${timestamp.microsecondsSinceEpoch}',
      role: role,
      content: content,
      createdAt: timestamp,
    );
  }

  AssistantContextModel _readAssistantContext() {
    try {
      return _readContext();
    } catch (_) {
      return AssistantContextModel.empty();
    }
  }

  String _fallbackAnswer(String question) {
    final normalized = question.toLowerCase();

    if (normalized.contains('soil') || normalized.contains('plant')) {
      return 'Based on the current app data I can still help with planting basics. Check soil moisture first, then confirm the soil is suitable before starting the rover planting process. For calamansi, peanut, and sitaw, avoid planting in waterlogged soil.';
    }

    if (normalized.contains('rover') || normalized.contains('battery')) {
      return 'Based on the current app data, check the Rover Control module for battery, seed level, camera, Wi-Fi, Bluetooth, and sensor status. Use Emergency Stop if planting is active and control needs to be interrupted.';
    }

    if (normalized.contains('stock') || normalized.contains('inventory')) {
      return 'Based on the current app data, use the Stocks module to review harvested produce quantity, status, transaction history, stock in, stock out, and adjustments.';
    }

    return 'Based on the current app data, I can help with SeedRover modules, crop monitoring, planting steps, sensor readings, inventory, and general farming questions.';
  }
}

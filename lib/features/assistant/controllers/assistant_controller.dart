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
  final List<DateTime> _recentRequests = [];

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

    final rateLimitMessage = _checkLocalRateLimit();
    if (rateLimitMessage != null) {
      state = state.copyWith(errorMessage: rateLimitMessage);
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
      final fallbackContext = _readAssistantContext();
      final detail = error is AssistantException
          ? error.message
          : 'Unexpected assistant error: $error';

      state = state.copyWith(
        messages: [
          ...nextMessages,
          _message(
            role: AssistantMessageRole.assistant,
            content:
                '${_fallbackAnswer(question, fallbackContext)}\n\nConnection detail: $detail',
          ),
        ],
        isSending: false,
        errorMessage: 'Using local fallback. Detail: $detail',
      );
    }
  }

  String? _checkLocalRateLimit() {
    final now = DateTime.now();
    _recentRequests.removeWhere(
      (timestamp) => now.difference(timestamp) > const Duration(minutes: 1),
    );

    if (_recentRequests.length >= 20) {
      return 'Rovie is receiving too many requests. Please wait a moment before asking again.';
    }

    _recentRequests.add(now);
    return null;
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

  String _fallbackAnswer(String question, AssistantContextModel context) {
    final normalized = question.toLowerCase();

    if (normalized.contains('analytics') ||
        normalized.contains('sell') ||
        normalized.contains('sales') ||
        normalized.contains('best month') ||
        normalized.contains('best time')) {
      final analytics = context.farmAnalytics;
      final currentSalesStatus = analytics['currentSalesStatus'];
      final bestMonth = analytics['bestObservedSalesMonth'];
      final topItems = analytics['topSoldItems'];
      final hints = analytics['recommendationHints'];

      if ((normalized.contains('current') ||
              normalized.contains('status') ||
              normalized.contains('now')) &&
          currentSalesStatus is Map) {
        final summary = currentSalesStatus['summary'] as String?;
        final latestSale = currentSalesStatus['latestSale'];
        final topItem =
            topItems is List && topItems.isNotEmpty ? topItems.first : null;
        final salesToday = currentSalesStatus['salesToday'];
        final salesThisMonth = currentSalesStatus['salesThisMonth'];
        final unitsSoldThisMonth = currentSalesStatus['unitsSoldThisMonth'];
        final salesTransactionsThisMonth =
            currentSalesStatus['salesTransactionsThisMonth'];
        final latestSaleText = latestSale is Map && latestSale['item'] != null
            ? ' Latest sale: ${latestSale['item']} (${latestSale['quantity']} ${latestSale['unit'] ?? ''}${latestSale['totalAmount'] == null ? '' : ', ${_formatPeso(latestSale['totalAmount'])}'}).'
            : '';
        final topItemText = topItem is Map && topItem['label'] != null
            ? ' Top sold item so far: ${topItem['label']}.'
            : '';
        final dashboardText =
            ' Dashboard sales: today ${_formatPeso(salesToday)}, this month ${_formatPeso(salesThisMonth)}, units sold ${_formatNumber(unitsSoldThisMonth)}, sales txns ${salesTransactionsThisMonth ?? 0}.';

        return 'Based on the current app data, ${summary ?? 'sales status is available from stock records.'}$dashboardText$latestSaleText$topItemText';
      }

      if (bestMonth is Map && bestMonth['label'] != null) {
        final firstTopItem =
            topItems is List && topItems.isNotEmpty ? topItems.first : null;
        final topItemText = firstTopItem is Map && firstTopItem['label'] != null
            ? ' Top item: ${firstTopItem['label']}.'
            : '';
        final confidenceText = hints is List && hints.isNotEmpty
            ? ' ${hints.last}'
            : '';

        return 'Based on the current app data, the strongest observed selling period is ${bestMonth['label']}.${topItemText}$confidenceText';
      }

      return 'Based on the current app data, I need more stock-out or sales history before I can suggest the best time of year to sell confidently.';
    }

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

  String _formatPeso(Object? value) {
    final amount = value is num ? value.toDouble() : 0;

    return 'PHP ${amount.toStringAsFixed(2)}';
  }

  String _formatNumber(Object? value) {
    final amount = value is num ? value.toDouble() : 0;

    return amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(1);
  }
}

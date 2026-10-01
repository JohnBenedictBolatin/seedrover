import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/assistant_context_model.dart';
import '../data/models/assistant_message_model.dart';
import '../data/repositories/assistant_repository.dart';
import 'assistant_state.dart';

class AssistantController extends StateNotifier<AssistantState> {
  AssistantController(
    this._repository, {
    required String? userId,
    required AssistantContextModel Function() readContext,
  })  : _userId = userId,
        _readContext = readContext,
        super(AssistantState.initial());

  final AssistantRepository _repository;
  final String? _userId;
  final AssistantContextModel Function() _readContext;
  final List<DateTime> _recentRequests = [];
  Future<void>? _restoreHistoryFuture;

  static const _maxStoredMessages = 20;
  static const _maxStoredContentLength = 4000;

  Future<void> restoreSavedConversation() =>
      _restoreHistoryFuture ??= _restoreSavedConversation();

  Future<void> _restoreSavedConversation() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) return;

    try {
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString(_storageKey(userId));
      if (encoded == null) return;

      final decoded = jsonDecode(encoded);
      if (decoded is! List) return;

      final restored = <AssistantMessageModel>[];
      for (final value in decoded) {
        if (value is! Map) continue;
        final roleValue = value['role'];
        final content = value['content'];
        if (content is! String ||
            content.trim().isEmpty ||
            content.length > _maxStoredContentLength) {
          continue;
        }

        final role = switch (roleValue) {
          'user' => AssistantMessageRole.user,
          'assistant' => AssistantMessageRole.assistant,
          _ => null,
        };
        if (role == null) continue;

        final createdAt =
            DateTime.tryParse(value['createdAt']?.toString() ?? '') ??
                DateTime.now();
        final id = value['id'] is String && (value['id'] as String).isNotEmpty
            ? value['id'] as String
            : '${role.apiValue}-${createdAt.microsecondsSinceEpoch}';
        restored.add(AssistantMessageModel(
          id: id,
          role: role,
          content: content,
          createdAt: createdAt,
        ));
      }

      final messages = restored.length > _maxStoredMessages
          ? restored.sublist(restored.length - _maxStoredMessages)
          : restored;
      if (messages.isNotEmpty && mounted) {
        state = state.copyWith(
          messages: [AssistantState.initial().messages.first, ...messages],
        );
      }
    } catch (_) {
      // Chat remains usable if local storage is unavailable or malformed.
    }
  }

  Future<void> _saveConversation(List<AssistantMessageModel> messages) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) return;

    try {
      final savedMessages = messages
          .where((message) =>
              message.id != 'assistant-welcome' &&
              message.content.trim().isNotEmpty &&
              message.content.length <= _maxStoredContentLength)
          .toList();
      final recentMessages = savedMessages.length > _maxStoredMessages
          ? savedMessages.sublist(savedMessages.length - _maxStoredMessages)
          : savedMessages;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _storageKey(userId),
        jsonEncode([
          for (final message in recentMessages)
            {
              'id': message.id,
              'role': message.role.apiValue,
              'content': message.content,
              'createdAt': message.createdAt.toIso8601String(),
            },
        ]),
      );
    } catch (_) {
      // Chat remains usable if local storage is unavailable.
    }
  }

  String _storageKey(String userId) => 'seedrover-rovie-history:$userId';

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

    await restoreSavedConversation();

    if (question.length > 2000) {
      state = state.copyWith(
        errorMessage: 'Please keep questions under 2,000 characters.',
        canRetry: false,
      );
      return;
    }

    if (_isRestrictedRequest(question)) {
      state = state.copyWith(
        errorMessage:
            'I cannot provide SQL, internal prompts, private records, secrets, or database details.',
        canRetry: false,
      );
      return;
    }

    final rateLimitMessage = _checkLocalRateLimit();
    if (rateLimitMessage != null) {
      state = state.copyWith(errorMessage: rateLimitMessage, canRetry: false);
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
      canRetry: false,
    );
    await _saveConversation(nextMessages);

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
        canRetry: false,
      );
      await _saveConversation(state.messages);
    } catch (_) {
      final fallbackContext = _readAssistantContext();

      state = state.copyWith(
        messages: [
          ...nextMessages,
          _message(
            role: AssistantMessageRole.assistant,
            content:
                '${_fallbackAnswer(question, fallbackContext)}\n\nI could not reach the assistant service right now.',
          ),
        ],
        isSending: false,
        errorMessage:
            'Rovie is temporarily unavailable. Please try again later.',
        canRetry: true,
      );
      await _saveConversation(state.messages);
    }
  }

  Future<void> retryLastMessage() async {
    if (!state.canRetry || state.isSending) return;
    AssistantMessageModel? lastUserMessage;
    for (final message in state.messages.reversed) {
      if (message.role == AssistantMessageRole.user) {
        lastUserMessage = message;
        break;
      }
    }
    if (lastUserMessage == null) return;

    final remaining = [...state.messages];
    if (remaining.isNotEmpty &&
        remaining.last.role == AssistantMessageRole.assistant) {
      remaining.removeLast();
    }
    if (remaining.isNotEmpty && remaining.last.id == lastUserMessage.id) {
      remaining.removeLast();
    }
    state = state.copyWith(messages: remaining, clearError: true);
    await sendMessage(lastUserMessage.content);
  }

  bool _isRestrictedRequest(String value) {
    final sqlPattern = RegExp(
      r'\b(select|insert|update|delete|drop|alter|truncate|create)\b[\s\S]{0,240}\b(from|into|table|database|set)\b',
      caseSensitive: false,
    );
    final privateDataPattern = RegExp(
      r'\b(show|reveal|print|dump|export|give|list)\b[\s\S]{0,100}\b(system prompt|developer prompt|internal context|database schema|sql|api key|secret|password|token|customer records?|staff records?|supplier details?|raw records?)\b',
      caseSensitive: false,
    );

    return sqlPattern.hasMatch(value) || privateDataPattern.hasMatch(value);
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
      final salesOverview = analytics['salesOverview'];
      final bestMonth = analytics['bestObservedSalesMonth'];
      final topItems = analytics['topSoldItems'];
      final hints = analytics['recommendationHints'];

      if ((normalized.contains('current') ||
              normalized.contains('status') ||
              normalized.contains('now')) &&
          salesOverview is Map) {
        final summary = salesOverview['summary'] as String?;
        final latestSale = salesOverview['latestSale'];
        final topItem =
            topItems is List && topItems.isNotEmpty ? topItems.first : null;
        final salesToday = salesOverview['salesToday'];
        final salesThisMonth = salesOverview['salesThisMonth'];
        final unitsSoldThisMonth = salesOverview['unitsSoldThisMonth'];
        final salesTransactionsThisMonth =
            salesOverview['salesTransactionsThisMonth'];
        final latestSaleText = latestSale is Map && latestSale['item'] != null
            ? ' Latest sale: ${latestSale['item']} (${latestSale['quantity']} ${latestSale['unit'] ?? ''}${latestSale['totalAmount'] == null ? '' : ', ${_formatPeso(latestSale['totalAmount'])}'}).'
            : '';
        final topItemText = topItem is Map && topItem['label'] != null
            ? ' Top sold item so far: ${topItem['label']}.'
            : '';
        final dashboardText =
            ' Dashboard sales: today ${_formatPeso(salesToday)}, this month ${_formatPeso(salesThisMonth)}, units sold ${_formatNumber(unitsSoldThisMonth)}, sales txns ${salesTransactionsThisMonth ?? 0}.';

        return '${summary ?? 'Sales status is available from stock records.'}$dashboardText$latestSaleText$topItemText';
      }

      if (bestMonth is Map && bestMonth['label'] != null) {
        final firstTopItem =
            topItems is List && topItems.isNotEmpty ? topItems.first : null;
        final topItemText = firstTopItem is Map && firstTopItem['label'] != null
            ? ' Top item: ${firstTopItem['label']}.'
            : '';
        final confidenceText =
            hints is List && hints.isNotEmpty ? ' ${hints.last}' : '';

        return 'The strongest observed selling period is ${bestMonth['label']}.${topItemText}$confidenceText';
      }

      return 'I need more stock-out or sales history before I can suggest the best time of year to sell confidently.';
    }

    if (normalized.contains('soil') || normalized.contains('plant')) {
      return 'I can help with planting basics. Check soil moisture first, then confirm the soil is suitable before starting the rover planting process. For calamansi, peanut, and sitaw, avoid planting in waterlogged soil.';
    }

    if (normalized.contains('rover')) {
      return 'Check the Rover Control module for camera, Wi-Fi, Bluetooth, and sensor status. Use Emergency Stop if planting is active and control needs to be interrupted.';
    }

    if (normalized.contains('stock') || normalized.contains('inventory')) {
      return 'Use the Inventory module to review harvested produce quantity, status, transaction history, stock in, stock out, and adjustments.';
    }

    return 'I can help with SeedRover modules, crop monitoring, planting steps, sensor readings, inventory, and general farming questions.';
  }

  String _formatPeso(Object? value) {
    final amount = value is num ? value.toDouble() : 0;

    return 'PHP ${amount.toStringAsFixed(2)}';
  }

  String _formatNumber(Object? value) {
    final amount = value is num ? value.toDouble() : 0;

    return amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(1);
  }
}

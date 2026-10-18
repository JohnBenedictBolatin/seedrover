import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/assistant_message_model.dart';
import '../data/repositories/assistant_repository.dart';
import 'assistant_state.dart';

class AssistantController extends StateNotifier<AssistantState> {
  AssistantController(
    this._repository, {
    required String? userId,
  })  : _userId = userId,
        super(AssistantState.initial());

  final AssistantRepository _repository;
  final String? _userId;
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

    final slowTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && state.isSending) {
        state = state.copyWith(showSlowMessage: true);
      }
    });
    try {
      final reply = await _repository.ask(
        question: question,
        history: nextMessages,
      );
      if (!mounted) return;
      state = state.copyWith(
        messages: [
          ...nextMessages,
          _message(role: AssistantMessageRole.assistant, content: reply.answer),
        ],
        isSending: false,
        canRetry: false,
        showSlowMessage: false,
        errorMessage: reply.notice,
      );
      await _saveConversation(state.messages);
    } on AssistantException catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isSending: false,
        errorMessage: _formatError(error),
        canRetry: ![
          'sign_in_required',
          'account_inactive',
          'permission_denied',
          'invalid_question',
          'question_too_long',
        ].contains(error.message),
        showSlowMessage: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isSending: false,
        errorMessage:
            'Could not connect to Rovie. Check your connection and retry.',
        canRetry: true,
        showSlowMessage: false,
      );
    } finally {
      slowTimer.cancel();
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

    final current = [...state.messages];
    if (current.isNotEmpty &&
        current.last.role == AssistantMessageRole.assistant) {
      current.removeLast();
    }
    state =
        state.copyWith(messages: current, isSending: true, clearError: true);
    await _saveConversation(current);
    final slowTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && state.isSending) {
        state = state.copyWith(showSlowMessage: true);
      }
    });
    try {
      final reply = await _repository.ask(
        question: lastUserMessage.content,
        history: current,
      );
      if (!mounted) return;
      state = state.copyWith(
        messages: [
          ...current,
          _message(role: AssistantMessageRole.assistant, content: reply.answer)
        ],
        isSending: false,
        canRetry: false,
        showSlowMessage: false,
        errorMessage: reply.notice,
      );
      await _saveConversation(state.messages);
    } on AssistantException catch (error) {
      if (!mounted) return;
      state = state.copyWith(
          isSending: false,
          errorMessage: _formatError(error),
          canRetry: _isRetryable(error.message),
          showSlowMessage: false);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
          isSending: false,
          errorMessage:
              'Could not connect to Rovie. Check your connection and retry.',
          canRetry: true,
          showSlowMessage: false);
    } finally {
      slowTimer.cancel();
    }
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

  String _friendlyError(String code) {
    return switch (code) {
      'sign_in_required' => 'Your session ended. Sign in again to ask Rovie.',
      'account_inactive' =>
        'This account is inactive. Ask an administrator for help.',
      'permission_denied' =>
        'Your account does not have access to that information.',
      'rate_limited' =>
        'Rovie is receiving too many requests. Please wait a moment, then retry.',
      'request_timeout' =>
        'Rovie is taking too long to respond. Your question is saved; retry when ready.',
      'invalid_question' => 'Please check your question and try again.',
      'question_too_long' => 'Please keep questions under 2,000 characters.',
      'farm_data_unavailable' =>
        'Farm information could not be loaded. Your question is saved; try again.',
      'timeout' =>
        'Rovie is taking too long to respond. Your question is saved; retry when ready.',
      _ =>
        'Rovie is temporarily unavailable. Your question is saved; try again.',
    };
  }

  String _formatError(AssistantException error) {
    final reference = error.requestId;
    return '${_friendlyError(error.message)}${reference == null ? '' : ' (Ref: $reference)'}';
  }

  bool _isRetryable(String code) => !const {
        'sign_in_required',
        'account_inactive',
        'permission_denied',
        'invalid_question',
      }.contains(code);
}

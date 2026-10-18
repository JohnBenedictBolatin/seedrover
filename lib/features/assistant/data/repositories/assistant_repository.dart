import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import '../models/assistant_message_model.dart';

class AssistantRepository {
  const AssistantRepository(this._client);

  final SupabaseClient _client;

  Future<AssistantReply> ask({
    required String question,
    required List<AssistantMessageModel> history,
  }) async {
    late final FunctionResponse response;

    try {
      response = await _client.functions.invoke(
        'assistant',
        body: {
          'question': question,
          'history': history.map((message) => message.toApiJson()).toList(),
        },
      ).timeout(const Duration(seconds: 30));
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map && details['code'] is String
          ? details['code'] as String
          : _codeForStatus(error.status);
      final requestId = details is Map && details['requestId'] is String
          ? details['requestId'] as String
          : null;
      throw AssistantException(code, requestId: requestId);
    } on TimeoutException {
      throw const AssistantException('timeout');
    } catch (_) {
      throw const AssistantException('connection_error');
    }

    if (response.status >= 400) {
      final code =
          response.data is Map ? response.data['code']?.toString() : null;
      final requestId =
          response.data is Map ? response.data['requestId']?.toString() : null;
      throw AssistantException(code ?? _codeForStatus(response.status),
          requestId: requestId);
    }

    final data = response.data;

    if (data is Map && data['answer'] is String) {
      final answer = (data['answer'] as String).trim();
      if (answer.isNotEmpty) {
        return AssistantReply(
          answer: answer,
          notice: data['notice'] is String ? data['notice'] as String : null,
          requestId:
              data['requestId'] is String ? data['requestId'] as String : null,
        );
      }
    }

    throw const AssistantException('The assistant returned an empty response.');
  }

  String _codeForStatus(int? status) {
    return switch (status) {
      401 => 'sign_in_required',
      403 => 'permission_denied',
      429 => 'rate_limited',
      504 => 'request_timeout',
      400 => 'invalid_question',
      _ => 'service_unavailable',
    };
  }
}

class AssistantReply {
  const AssistantReply({required this.answer, this.notice, this.requestId});

  final String answer;
  final String? notice;
  final String? requestId;
}

class AssistantException implements Exception {
  const AssistantException(this.message, {this.requestId});

  final String message;
  final String? requestId;

  @override
  String toString() => message;
}

final assistantRepositoryProvider = Provider<AssistantRepository>(
  (ref) => AssistantRepository(ref.watch(supabaseClientProvider)),
);

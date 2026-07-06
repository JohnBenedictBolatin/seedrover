import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import '../models/assistant_context_model.dart';
import '../models/assistant_message_model.dart';

class AssistantRepository {
  const AssistantRepository(this._client);

  final SupabaseClient _client;

  Future<String> ask({
    required String question,
    required List<AssistantMessageModel> history,
    required AssistantContextModel context,
  }) async {
    late final FunctionResponse response;

    try {
      response = await _client.functions.invoke(
        'assistant',
        body: {
          'question': question,
          'history': history.map((message) => message.toApiJson()).toList(),
          'context': context.toApiJson(),
        },
      );
    } on FunctionException catch (error) {
      throw AssistantException(
        'Edge Function ${error.status}: ${_formatFunctionDetails(error)}',
      );
    } catch (error) {
      throw AssistantException('Assistant request failed: $error');
    }

    if (response.status >= 400) {
      throw AssistantException(
        'Edge Function ${response.status}: ${_formatResponseData(response.data)}',
      );
    }

    final data = response.data;

    if (data is Map && data['answer'] is String) {
      return (data['answer'] as String).trim();
    }

    throw const AssistantException('The assistant returned an empty response.');
  }

  String _formatFunctionDetails(FunctionException error) {
    final details = error.details;

    if (details != null) {
      return _formatResponseData(details);
    }

    return error.reasonPhrase ?? 'No details returned.';
  }

  String _formatResponseData(dynamic data) {
    if (data is Map) {
      final messageParts = [
        data['error'],
        data['message'],
        data['details'],
      ].whereType<Object>().map((value) => value.toString()).toList();

      if (messageParts.isNotEmpty) {
        return messageParts.join(' - ');
      }
    }

    if (data != null) {
      return data.toString();
    }

    return 'No details returned.';
  }
}

class AssistantException implements Exception {
  const AssistantException(this.message);

  final String message;

  @override
  String toString() => message;
}

final assistantRepositoryProvider = Provider<AssistantRepository>(
  (ref) => AssistantRepository(ref.watch(supabaseClientProvider)),
);

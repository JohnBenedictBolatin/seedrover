import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/features/assistant/controllers/assistant_controller.dart';
import 'package:seedrover/features/assistant/data/models/assistant_message_model.dart';
import 'package:seedrover/features/assistant/data/repositories/assistant_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RetryingAssistantRepository extends AssistantRepository {
  _RetryingAssistantRepository()
      : super(SupabaseClient('http://localhost', 'test-key'));

  var calls = 0;

  @override
  Future<AssistantReply> ask({
    required String question,
    required List<AssistantMessageModel> history,
  }) async {
    calls += 1;
    if (calls == 1)
      throw const AssistantException('service_unavailable',
          requestId: 'req-123');
    return const AssistantReply(answer: 'I found the verified result.');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test(
      'failed chat turn stays visible and retry updates it without duplication',
      () async {
    final repository = _RetryingAssistantRepository();
    final controller =
        AssistantController(repository, userId: 'farmer:inventory');
    addTearDown(controller.dispose);

    await controller.sendMessage('my recent sales');

    expect(
        controller.state.messages
            .where((message) => message.role == AssistantMessageRole.user),
        hasLength(1));
    expect(
        controller.state.messages
            .where((message) => message.role == AssistantMessageRole.assistant),
        hasLength(1));
    expect(controller.state.errorMessage, contains('req-123'));
    expect(controller.state.canRetry, isTrue);

    await controller.retryLastMessage();

    expect(repository.calls, 2);
    expect(
        controller.state.messages
            .where((message) => message.role == AssistantMessageRole.user),
        hasLength(1));
    expect(
        controller.state.messages
            .where((message) => message.role == AssistantMessageRole.assistant),
        hasLength(2));
    expect(
        controller.state.messages.last.content, 'I found the verified result.');
    expect(controller.state.errorMessage, isNull);
    expect(controller.state.isSending, isFalse);
  });
}

import 'package:diabeatthis/core/llm/firebase_ai_llm_client.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final item in [
    (
      FirebaseAIException('models/test is not found'),
      LlmRequestFailure.unavailable,
    ),
    (QuotaExceeded('quota exceeded'), LlmRequestFailure.quotaExceeded),
    (InvalidApiKey('invalid key'), LlmRequestFailure.unauthorized),
    (
      FirebaseAIException('PERMISSION_DENIED: App Check failed'),
      LlmRequestFailure.unauthorized,
    ),
    (
      FirebaseAISdkException('Unexpected response format'),
      LlmRequestFailure.unavailable,
    ),
  ]) {
    test(
      'maps SDK ${item.$1.runtimeType} and retains provider diagnostics',
      () async {
        final client = FirebaseAiLlmClient(gateway: ThrowingAiGateway(item.$1));
        await expectLater(
          client.generate(const LocalLlmRequest(prompt: 'test')),
          throwsA(
            isA<LlmRequestException>()
                .having((e) => e.failure, 'failure', item.$2)
                .having((e) => e.cause, 'cause', same(item.$1))
                .having((e) => e.message, 'provider message', isNotEmpty),
          ),
        );
      },
    );
  }
}

class ThrowingAiGateway extends FirebaseAiGenerateContentGateway {
  final Object error;
  const ThrowingAiGateway(this.error);
  @override
  Future<String> generate({
    required String modelName,
    required String prompt,
    required List<LlmImageData> images,
  }) async => throw error;
}

import 'package:diabeatthis/common/ai/ai_client_factory.dart';
import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';

import 'recording_ai_test_client.dart';

class RecordingAiClientFactory extends AiClientFactory {
  RecordingAiClientFactory({
    required super.credentials,
    required super.chatGptAuth,
  });

  final client = RecordingAiTestClient();
  final configurations = <AiConfiguration>[];
  final keys = <String?>[];
  final outputLimits = <int>[];
  final thinkingBudgets = <int?>[];

  @override
  LocalLlmClient create(
    AiConfiguration configuration, {
    String? apiKey,
    int maxOutputTokens = 8192,
    int? thinkingBudget = 2048,
  }) {
    configurations.add(configuration);
    keys.add(apiKey);
    outputLimits.add(maxOutputTokens);
    thinkingBudgets.add(thinkingBudget);
    return client;
  }
}

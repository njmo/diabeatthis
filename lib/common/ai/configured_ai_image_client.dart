import 'dart:async';
import 'dart:typed_data';

import '../../core/llm/local_llm_client.dart';
import 'ai_configuration.dart';
import 'ai_image_client.dart';

class ConfiguredAiImageClient implements AiImageClient {
  const ConfiguredAiImageClient({
    required this.configuration,
    required this.createClient,
    this.timeout = const Duration(seconds: 120),
  });

  final Future<AiConfiguration> configuration;
  final AiImageClient Function(AiConfiguration, {required Duration timeout})
  createClient;
  final Duration timeout;

  @override
  Future<Uint8List> generate(String prompt) async {
    final elapsed = Stopwatch()..start();
    try {
      final settings = await configuration.timeout(timeout);
      final remaining = timeout - elapsed.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('AI configuration timed out.');
      }
      return await createClient(settings, timeout: remaining).generate(prompt);
    } on TimeoutException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.timeout,
        message: 'AI image generation timed out.',
      );
    }
  }
}

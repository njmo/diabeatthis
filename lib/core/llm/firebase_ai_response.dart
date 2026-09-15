import 'package:firebase_ai/firebase_ai.dart';

import '../logger/logger.dart';
import 'llm_output_limit_exception.dart';

String readFirebaseAiResponse(GenerateContentResponse response) {
  final finishReason = response.candidates.firstOrNull?.finishReason;
  final usage = response.usageMetadata;
  Log.i(
    'FirebaseAiResponse',
    'finishReason=${finishReason?.name}, '
        'outputTokens=${usage?.candidatesTokenCount}, '
        'thinkingTokens=${usage?.thoughtsTokenCount}',
  );
  final text = response.text;
  if (finishReason == FinishReason.maxTokens) {
    throw LlmOutputLimitException(text ?? '');
  }
  if (text == null || text.trim().isEmpty) {
    throw const FormatException('Firebase AI returned an empty response');
  }
  return text;
}

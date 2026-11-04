import 'package:flutter/foundation.dart';

import '../../../../core/llm/llm_output_limit_exception.dart';
import '../../../../core/llm/local_llm_client.dart';
import '../../../../core/logger/logger.dart';

/// Reports failure categories without logging photos, prompts or model output.
String describeMealPhotoFailure(Object error) => switch (error) {
  LlmOutputLimitException() => 'response.output_limit',
  LlmRequestException(:final failure) => 'request.${failure.name}',
  LocalLlmUnavailableException() => 'request.not_configured',
  FormatException(:final message) => switch (message) {
    'Unsupported meal photo schema' => 'response.unsupported_schema',
    'Grounding changed recognized food descriptors' =>
      'response.changed_descriptors',
    'Reference identity changed' => 'response.changed_reference',
    'Unknown candidate identity' => 'response.unknown_candidate',
    _ => 'response.invalid_format',
  },
  ArgumentError() => 'request.invalid_input',
  _ => error.runtimeType.toString(),
};

/// Release builds retain only bounded stage metadata, never model/user content.
void recordMealPhotoDiagnostic(
  String message, {
  bool failed = false,
  StackTrace? stackTrace,
}) {
  if (failed) {
    Log.e('MealPhotoController', message, stackTrace: stackTrace);
  } else {
    Log.i('MealPhotoController', message);
  }
  if (!kDebugMode) debugPrint('[MealPhotoController] $message');
}

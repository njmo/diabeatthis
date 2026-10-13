import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_ai_llm_client.dart';
import 'local_llm_client.dart';

const analysisFirebaseModel = 'gemini-2.5-flash';

/// Shared remote default. Each analysis client is a separate replaceable port.
final analysisLlmTransportProvider = Provider<LocalLlmClient>(
  (ref) => const FirebaseAiLlmClient(
    modelName: analysisFirebaseModel,
    gateway: FirebaseAiGenerateContentGateway(
      maxOutputTokens: 8192,
      thinkingBudget: 2048,
    ),
  ),
);

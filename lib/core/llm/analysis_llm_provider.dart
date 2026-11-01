import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/ai/ai_client_providers.dart';
import 'local_llm_client.dart';

const analysisFirebaseModel = 'gemini-2.5-flash';

/// Shared configured transport. Each analysis client remains a replaceable port.
final analysisLlmTransportProvider = Provider<LocalLlmClient>(
  (ref) => ref.watch(aiAnalysisClientProvider),
);

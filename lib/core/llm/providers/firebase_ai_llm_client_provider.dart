import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/ai/ai_client_providers.dart';
import '../local_llm_client.dart';

part 'firebase_ai_llm_client_provider.g.dart';

@riverpod
LocalLlmClient firebaseAiLlmClient(Ref ref) {
  // Compatibility entry point: even legacy callers honor the selected provider.
  return ref.watch(aiPhotoClientProvider);
}

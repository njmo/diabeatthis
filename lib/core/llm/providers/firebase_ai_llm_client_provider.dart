import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../firebase_ai_llm_client.dart';
import '../local_llm_client.dart';

part 'firebase_ai_llm_client_provider.g.dart';

@riverpod
LocalLlmClient firebaseAiLlmClient(Ref ref) {
  return const FirebaseAiLlmClient();
}

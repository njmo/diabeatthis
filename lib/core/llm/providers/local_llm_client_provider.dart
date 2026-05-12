import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../flutter_gemma_local_llm_client.dart';
import '../local_llm_client.dart';

part 'local_llm_client_provider.g.dart';

@riverpod
LocalLlmClient localLlmClient(Ref ref) {
  return const FlutterGemmaLocalLlmClient();
}

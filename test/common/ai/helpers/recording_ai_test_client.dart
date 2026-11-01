import 'package:diabeatthis/core/llm/local_llm_client.dart';

class RecordingAiTestClient implements LocalLlmClient {
  final requests = <LocalLlmRequest>[];
  String response = '{"ok":true}';
  Object? error;

  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async {
    requests.add(request);
    if (error != null) throw error!;
    return LocalLlmResponse(text: response);
  }
}

import 'dart:async';

import 'package:diabeatthis/core/llm/local_llm_client.dart';

class PendingIconTestClient implements LocalLlmClient {
  final requests = <LocalLlmRequest>[];
  final response = Completer<LocalLlmResponse>();

  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) {
    requests.add(request);
    return response.future;
  }
}

class LocalLlmRequest {
  final String prompt;
  final List<String> imagePaths;
  final Duration? timeout;

  const LocalLlmRequest({
    required this.prompt,
    this.imagePaths = const [],
    this.timeout,
  });

  bool get hasImages => imagePaths.isNotEmpty;
}

class LocalLlmResponse {
  final String text;

  const LocalLlmResponse({required this.text});
}

abstract interface class LocalLlmClient {
  Future<LocalLlmResponse> generate(LocalLlmRequest request);
}

class LocalLlmUnavailableException implements Exception {
  final String message;

  const LocalLlmUnavailableException([
    this.message = 'Local LLM is unavailable',
  ]);

  @override
  String toString() => 'LocalLlmUnavailableException: $message';
}

class LocalLlmUnavailableClient implements LocalLlmClient {
  const LocalLlmUnavailableClient();

  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async {
    throw const LocalLlmUnavailableException();
  }
}

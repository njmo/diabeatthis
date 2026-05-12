import 'dart:io';
import 'dart:typed_data';

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

class LlmImageData {
  final Uint8List bytes;
  final String mimeType;

  const LlmImageData({required this.bytes, required this.mimeType});
}

abstract interface class LlmImageLoader {
  Future<List<LlmImageData>> loadAll(List<String> imagePaths);
}

class FileLlmImageLoader implements LlmImageLoader {
  const FileLlmImageLoader();

  @override
  Future<List<LlmImageData>> loadAll(List<String> imagePaths) {
    return Future.wait(imagePaths.map(_load));
  }

  Future<LlmImageData> _load(String path) async {
    return LlmImageData(
      bytes: await File(path).readAsBytes(),
      mimeType: _mimeTypeForPath(path),
    );
  }
}

String _mimeTypeForPath(String path) {
  final lowerPath = path.toLowerCase();
  if (lowerPath.endsWith('.png')) {
    return 'image/png';
  }
  if (lowerPath.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lowerPath.endsWith('.heic')) {
    return 'image/heic';
  }
  if (lowerPath.endsWith('.heif')) {
    return 'image/heif';
  }
  return 'image/jpeg';
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

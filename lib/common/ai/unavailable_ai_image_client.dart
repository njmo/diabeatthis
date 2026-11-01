import 'dart:typed_data';

import 'ai_capability_unavailable_exception.dart';
import 'ai_image_client.dart';

class UnavailableAiImageClient implements AiImageClient {
  const UnavailableAiImageClient();

  @override
  Future<Uint8List> generate(String prompt) =>
      unavailableAiImageGeneration(prompt);
}

Future<Uint8List> unavailableAiImageGeneration(String prompt) async {
  throw const AiCapabilityUnavailableException();
}

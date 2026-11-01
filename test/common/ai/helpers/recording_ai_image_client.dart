import 'dart:typed_data';

import 'package:diabeatthis/common/ai/ai_image_client.dart';

class RecordingAiImageClient implements AiImageClient {
  final prompts = <String>[];
  final bytes = Uint8List.fromList([1, 2, 3]);
  Object? error;

  @override
  Future<Uint8List> generate(String prompt) async {
    prompts.add(prompt);
    if (error != null) throw error!;
    return bytes;
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../common/ai/ai_image_client.dart';
import 'firebase_ai_llm_client.dart';
import 'local_llm_client.dart';

class FirebaseAiImageClient implements AiImageClient {
  const FirebaseAiImageClient({
    this.modelName = 'gemini-3.1-flash-image',
    this.timeout = const Duration(seconds: 120),
  });

  final String modelName;
  final Duration timeout;

  @override
  Future<Uint8List> generate(String prompt) async {
    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: modelName,
        generationConfig: GenerationConfig(
          responseModalities: [ResponseModalities.image],
          imageConfig: const ImageConfig(
            aspectRatio: ImageAspectRatio.square1x1,
            imageSize: ImageSize.size512,
          ),
        ),
      );
      final response = await model
          .generateContent([Content.text(prompt)])
          .timeout(timeout);
      final image = response.inlineDataParts.firstOrNull;
      if (image == null) throw const FormatException('AI returned no image');
      return image.bytes;
    } on FirebaseAIException catch (error) {
      throw LlmRequestException(
        failure: firebaseAiRequestException(error).failure,
        message: 'Firebase AI image generation failed.',
      );
    } on TimeoutException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.timeout,
        message: 'Firebase AI image generation timed out.',
      );
    } on SocketException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.network,
        message: 'Firebase AI network request failed.',
      );
    } on FirebaseAISdkException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.unavailable,
        message: 'Firebase AI image generation is unavailable.',
      );
    } on FirebaseException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.unavailable,
        message: 'Firebase AI image generation is unavailable.',
      );
    }
  }
}

import 'dart:async';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';

import 'local_llm_client.dart';

const firebaseAiDefaultModel = 'gemini-2.5-flash';

class FirebaseAiLlmClient implements LocalLlmClient {
  final FirebaseAiGenerateContentGateway gateway;
  final LlmImageLoader imageLoader;
  final String modelName;

  const FirebaseAiLlmClient({
    this.gateway = const FirebaseAiGenerateContentGateway(),
    this.imageLoader = const FileLlmImageLoader(),
    this.modelName = firebaseAiDefaultModel,
  });

  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async {
    try {
      final operation = _generate(request);
      final timeout = request.timeout;
      return timeout == null
          ? await operation
          : await operation.timeout(timeout);
    } on TimeoutException catch (error) {
      throw LlmRequestException(
        failure: LlmRequestFailure.timeout,
        message: 'Firebase AI request timed out.',
        cause: error,
      );
    } on SocketException catch (error) {
      throw LlmRequestException(
        failure: LlmRequestFailure.network,
        message: 'Firebase AI network request failed.',
        cause: error,
      );
    } on FirebaseException catch (error) {
      throw LlmRequestException(
        failure: _firebaseFailure(error),
        message: error.message ?? 'Firebase AI request failed.',
        cause: error,
      );
    }
  }

  Future<LocalLlmResponse> _generate(LocalLlmRequest request) async {
    final images = await imageLoader.loadAll(request.imagePaths);
    final text = await gateway.generate(
      modelName: modelName,
      prompt: request.prompt,
      images: images,
    );
    return LocalLlmResponse(text: text);
  }
}

LlmRequestFailure _firebaseFailure(FirebaseException error) {
  final code = error.code.toLowerCase();
  final message = error.message?.toLowerCase() ?? '';
  if (code.contains('resource-exhausted') || code.contains('quota')) {
    return LlmRequestFailure.quotaExceeded;
  }
  if (code.contains('permission') ||
      code.contains('unauth') ||
      code.contains('app-check') ||
      message.contains('app attestation failed') ||
      message.contains('app check') ||
      message.contains('code: 403')) {
    return LlmRequestFailure.unauthorized;
  }
  if (code.contains('deadline') || code.contains('timeout')) {
    return LlmRequestFailure.timeout;
  }
  if (code.contains('network') || code.contains('unavailable')) {
    return LlmRequestFailure.network;
  }
  return LlmRequestFailure.unavailable;
}

class FirebaseAiGenerateContentGateway {
  const FirebaseAiGenerateContentGateway();

  Future<String> generate({
    required String modelName,
    required String prompt,
    required List<LlmImageData> images,
  }) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: modelName,
      generationConfig: GenerationConfig(
        maxOutputTokens: 2048,
        temperature: 0.1,
        responseMimeType: 'application/json',
      ),
    );
    final response = await model.generateContent([
      Content.multi([
        TextPart(prompt),
        for (final image in images) InlineDataPart(image.mimeType, image.bytes),
      ]),
    ]);
    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw const FormatException('Firebase AI returned an empty response');
    }
    return text;
  }
}

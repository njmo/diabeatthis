import 'dart:async';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_ai_response.dart';
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
    } on FirebaseAIException catch (error) {
      throw firebaseAiRequestException(error);
    } on FirebaseAISdkException catch (error) {
      throw LlmRequestException(
        failure: LlmRequestFailure.unavailable,
        message: error.message,
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

LlmRequestException firebaseAiRequestException(FirebaseAIException error) =>
    LlmRequestException(
      failure: error is QuotaExceeded
          ? LlmRequestFailure.quotaExceeded
          : error is InvalidApiKey
          ? LlmRequestFailure.unauthorized
          : _firebaseFailureMessage(error.message),
      message: error.message,
      cause: error,
    );

LlmRequestFailure _firebaseFailure(FirebaseException error) {
  return _firebaseFailureMessage(error.message ?? '', code: error.code);
}

LlmRequestFailure _firebaseFailureMessage(String text, {String code = ''}) {
  code = code.toLowerCase();
  final message = text.toLowerCase();
  if (code.contains('resource-exhausted') ||
      code.contains('quota') ||
      message.contains('resource_exhausted') ||
      message.contains('quota exceeded')) {
    return LlmRequestFailure.quotaExceeded;
  }
  if (code.contains('permission') ||
      code.contains('unauth') ||
      code.contains('app-check') ||
      message.contains('app attestation failed') ||
      message.contains('app check') ||
      message.contains('code: 403') ||
      message.contains('permission_denied') ||
      message.contains('unauthenticated')) {
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
  final int maxOutputTokens;
  final int? thinkingBudget;

  const FirebaseAiGenerateContentGateway({
    this.maxOutputTokens = 2048,
    this.thinkingBudget,
  });

  GenerationConfig get generationConfig => GenerationConfig(
    maxOutputTokens: maxOutputTokens,
    temperature: 0.1,
    responseMimeType: 'application/json',
    thinkingConfig: thinkingBudget == null
        ? null
        : ThinkingConfig.withThinkingBudget(thinkingBudget),
  );

  Future<String> generate({
    required String modelName,
    required String prompt,
    required List<LlmImageData> images,
  }) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: modelName,
      generationConfig: generationConfig,
    );
    final response = await model.generateContent([
      Content.multi([
        TextPart(prompt),
        for (final image in images) InlineDataPart(image.mimeType, image.bytes),
      ]),
    ]);
    return readFirebaseAiResponse(response);
  }
}

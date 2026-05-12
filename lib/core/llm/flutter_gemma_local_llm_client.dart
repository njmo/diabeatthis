import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart';

import 'local_llm_client.dart';

class FlutterGemmaLocalLlmClient implements LocalLlmClient {
  final FlutterGemmaInferenceGateway gateway;
  final LocalLlmImageLoader imageLoader;
  final int maxTokens;
  final PreferredBackend? preferredBackend;

  const FlutterGemmaLocalLlmClient({
    this.gateway = const FlutterGemmaInferenceGateway(),
    this.imageLoader = const FileLocalLlmImageLoader(),
    this.maxTokens = 4096,
    this.preferredBackend,
  });

  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) {
    final operation = _generate(request);
    final timeout = request.timeout;
    return timeout == null ? operation : operation.timeout(timeout);
  }

  Future<LocalLlmResponse> _generate(LocalLlmRequest request) async {
    try {
      final imageBytes = await imageLoader.loadAll(request.imagePaths);
      final text = await gateway.generate(
        prompt: request.prompt,
        imageBytes: imageBytes,
        maxTokens: maxTokens,
        preferredBackend: preferredBackend,
      );
      return LocalLlmResponse(text: text);
    } on LocalLlmUnavailableException {
      rethrow;
    } on StateError catch (error) {
      if (error.message.contains('No active inference model')) {
        throw const LocalLlmUnavailableException(
          'No active Flutter Gemma model is configured',
        );
      }
      rethrow;
    }
  }
}

abstract interface class LocalLlmImageLoader {
  Future<List<Uint8List>> loadAll(List<String> imagePaths);
}

class FileLocalLlmImageLoader implements LocalLlmImageLoader {
  const FileLocalLlmImageLoader();

  @override
  Future<List<Uint8List>> loadAll(List<String> imagePaths) {
    return Future.wait(imagePaths.map((path) => File(path).readAsBytes()));
  }
}

class FlutterGemmaInferenceGateway {
  const FlutterGemmaInferenceGateway();

  Future<String> generate({
    required String prompt,
    required List<Uint8List> imageBytes,
    required int maxTokens,
    PreferredBackend? preferredBackend,
  }) async {
    await FlutterGemma.initialize();
    final hasImages = imageBytes.isNotEmpty;
    final model = await FlutterGemma.getActiveModel(
      maxTokens: maxTokens,
      preferredBackend: preferredBackend,
      supportImage: hasImages,
      maxNumImages: hasImages ? imageBytes.length : null,
    );

    try {
      final chat = await model.createChat(
        modelType: ModelType.gemmaIt,
        supportImage: hasImages,
      );
      await _addPrompt(chat, prompt, imageBytes);
      return _responseText(await chat.generateChatResponse());
    } finally {
      await model.close();
    }
  }

  Future<void> _addPrompt(
    InferenceChat chat,
    String prompt,
    List<Uint8List> imageBytes,
  ) async {
    if (imageBytes.isEmpty) {
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
      return;
    }

    for (var index = 0; index < imageBytes.length; index += 1) {
      await chat.addQueryChunk(
        Message.withImage(
          text: index == 0 ? prompt : 'Additional input image ${index + 1}.',
          imageBytes: imageBytes[index],
          isUser: true,
        ),
      );
    }
  }

  String _responseText(ModelResponse response) {
    return switch (response) {
      TextResponse(:final token) => token,
      ThinkingResponse(:final content) => content,
      FunctionCallResponse(:final name, :final args) => jsonEncode({
        'name': name,
        'args': args,
      }),
    };
  }
}

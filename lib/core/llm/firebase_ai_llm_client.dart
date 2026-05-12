import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';

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
  Future<LocalLlmResponse> generate(LocalLlmRequest request) {
    final operation = _generate(request);
    final timeout = request.timeout;
    return timeout == null ? operation : operation.timeout(timeout);
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

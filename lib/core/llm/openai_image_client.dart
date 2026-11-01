import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../common/ai/ai_image_client.dart';
import 'local_llm_client.dart';
import 'openai_request_exception.dart';

/// Uses an API key; ChatGPT plan OAuth does not support image generation.
class OpenAiImageClient implements AiImageClient {
  const OpenAiImageClient({
    required this.accessToken,
    this.modelName = 'gpt-image-2.5-flare',
    this.client,
    this.timeout = const Duration(seconds: 120),
  });

  final Future<String> Function() accessToken;
  final String modelName;
  final http.Client? client;
  final Duration timeout;

  @override
  Future<Uint8List> generate(String prompt) async {
    final connection = client ?? http.Client();
    final abort = Completer<void>();
    try {
      return await _generate(prompt, connection, abort).timeout(
        timeout,
        onTimeout: () {
          if (!abort.isCompleted) abort.complete();
          throw const LlmRequestException(
            failure: LlmRequestFailure.timeout,
            message: 'OpenAI image generation timed out.',
          );
        },
      );
    } on TimeoutException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.timeout,
        message: 'OpenAI image generation timed out.',
      );
    } on http.ClientException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.network,
        message: 'OpenAI image generation network request failed.',
      );
    } on SocketException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.network,
        message: 'OpenAI image generation network request failed.',
      );
    } on FormatException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.unavailable,
        message: 'OpenAI returned an invalid image response.',
      );
    } finally {
      if (!abort.isCompleted) abort.complete();
      if (client == null) connection.close();
    }
  }

  Future<Uint8List> _generate(
    String prompt,
    http.Client connection,
    Completer<void> abort,
  ) async {
    if (prompt.trim().isEmpty || modelName.trim().isEmpty) {
      throw const LlmRequestException(
        failure: LlmRequestFailure.unavailable,
        message: 'An image prompt and model are required.',
      );
    }
    final token = (await accessToken()).trim();
    if (abort.isCompleted) throw http.RequestAbortedException();
    if (token.isEmpty) throw openAiRequestException(statusCode: 401);
    final request = http.AbortableRequest(
      'POST',
      Uri.parse('https://api.openai.com/v1/images/generations'),
      abortTrigger: abort.future,
    );
    request.followRedirects = false;
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    });
    request.body = jsonEncode({
      'model': modelName,
      'prompt': prompt,
      'n': 1,
      'output_format': 'png',
      'background': 'opaque',
      'size': '1024x1024',
      'quality': 'low',
    });
    final response = await connection.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.listen((_) {}).cancel();
      throw openAiRequestException(statusCode: response.statusCode);
    }
    final payload = jsonDecode(await _readBody(response.stream, abort.future));
    if (payload is! Map || payload['data'] is! List) {
      throw const FormatException('Invalid image response');
    }
    final data = payload['data'] as List;
    if (data.isEmpty || data.first is! Map) {
      throw const FormatException('Missing generated image');
    }
    final encoded = (data.first as Map)['b64_json'];
    if (encoded is! String || encoded.isEmpty) {
      throw const FormatException('Missing generated image bytes');
    }
    final bytes = base64Decode(encoded);
    if (bytes.isEmpty) throw const FormatException('Empty generated image');
    return bytes;
  }

  Future<String> _readBody(
    Stream<List<int>> stream,
    Future<void> abortTrigger,
  ) async {
    final iterator = StreamIterator(stream);
    unawaited(abortTrigger.then((_) => iterator.cancel()));
    final bytes = BytesBuilder(copy: false);
    try {
      while (await iterator.moveNext()) {
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } finally {
      await iterator.cancel();
    }
  }
}

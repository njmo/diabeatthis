import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../common/ai/ai_response_diagnostics.dart';
import 'llm_output_limit_exception.dart';
import 'local_llm_client.dart';
import 'openai_request_exception.dart';
import 'openai_response_stream.dart';

class OpenAiLlmClient implements LocalLlmClient {
  const OpenAiLlmClient({
    required this.modelName,
    required this.accessToken,
    this.useChatGptPlan = false,
    this.maxOutputTokens = 8192,
    this.client,
    this.imageLoader = const FileLlmImageLoader(),
  });

  final String modelName;
  final Future<String> Function() accessToken;
  final bool useChatGptPlan;
  final int maxOutputTokens;
  final http.Client? client;
  final LlmImageLoader imageLoader;

  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async {
    final transport = client ?? http.Client();
    final abort = Completer<void>();
    try {
      final operation = _generate(request, transport, abort);
      final response = await operation.timeout(
        request.timeout ?? const Duration(seconds: 90),
        onTimeout: () {
          if (!abort.isCompleted) abort.complete();
          throw const LlmRequestException(
            failure: LlmRequestFailure.timeout,
            message: 'OpenAI request timed out.',
          );
        },
      );
      return LocalLlmResponse(text: response);
    } on TimeoutException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.timeout,
        message: 'OpenAI request timed out.',
      );
    } on http.ClientException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.network,
        message: 'OpenAI network request failed.',
      );
    } on SocketException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.network,
        message: 'OpenAI network request failed.',
      );
    } on LlmOutputLimitException {
      rethrow;
    } on FormatException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.unavailable,
        message: 'OpenAI returned an invalid response.',
      );
    } finally {
      if (!abort.isCompleted) abort.complete();
      if (client == null) transport.close();
    }
  }

  Future<String> _generate(
    LocalLlmRequest request,
    http.Client transport,
    Completer<void> abort,
  ) async {
    final diagnosticId = DateTime.now().microsecondsSinceEpoch.toString();
    void diagnostic(String stage, String payload) => printAiResponseDiagnostic(
      tag: 'OpenAiTransport',
      requestId: diagnosticId,
      stage: stage,
      response: payload,
    );
    final token = (await accessToken()).trim();
    if (token.isEmpty) throw openAiRequestException(statusCode: 401);
    final images = await imageLoader.loadAll(request.imagePaths);
    if (abort.isCompleted) throw http.RequestAbortedException();
    final httpRequest = http.AbortableRequest(
      'POST',
      Uri.parse('https://api.openai.com/v1/responses'),
      abortTrigger: abort.future,
    );
    httpRequest.followRedirects = false;
    httpRequest.headers.addAll({
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    });
    httpRequest.body = jsonEncode({
      'model': modelName,
      'store': false,
      'stream': true,
      if (!useChatGptPlan)
        'max_output_tokens': request.maxOutputTokens ?? maxOutputTokens,
      'input': [
        {
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': request.prompt},
            for (final image in images)
              {
                'type': 'input_image',
                'image_url':
                    'data:${image.mimeType};base64,${base64Encode(image.bytes)}',
              },
          ],
        },
      ],
    });
    diagnostic(
      'request',
      jsonEncode({
        'model': modelName,
        'imageCount': images.length,
        'useChatGptPlan': useChatGptPlan,
        'maxOutputTokens': useChatGptPlan
            ? null
            : request.maxOutputTokens ?? maxOutputTokens,
      }),
    );
    final response = await transport.send(httpRequest);
    diagnostic(
      'http',
      jsonEncode({
        'status': response.statusCode,
        'requestId': response.headers['x-request-id'],
        'contentType': response.headers['content-type'],
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      diagnostic('http_error', body);
      throw openAiRequestException(statusCode: response.statusCode);
    }
    return OpenAiResponseStream(
      onRawEvent: (payload) => diagnostic('sse', payload),
    ).read(response.stream, abortTrigger: abort.future);
  }
}

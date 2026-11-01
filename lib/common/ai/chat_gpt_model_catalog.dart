import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/llm/local_llm_client.dart';
import 'ai_model_option.dart';

class ChatGptModelCatalog {
  const ChatGptModelCatalog({required this.accessToken, this.client});

  final Future<String> Function() accessToken;
  final http.Client? client;

  Future<List<AiModelOption>> load() async {
    final connection = client ?? http.Client();
    final abort = Completer<void>();
    try {
      return await _load(
        connection,
        abort,
      ).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.timeout,
        message: 'Model lookup timed out.',
      );
    } on SocketException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.network,
        message: 'Model lookup failed.',
      );
    } on http.ClientException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.network,
        message: 'Model lookup failed.',
      );
    } on FormatException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.unavailable,
        message: 'Invalid model catalog.',
      );
    } finally {
      if (!abort.isCompleted) abort.complete();
      if (client == null) connection.close();
    }
  }

  Future<List<AiModelOption>> _load(
    http.Client connection,
    Completer<void> abort,
  ) async {
    final token = (await accessToken()).trim();
    if (abort.isCompleted) throw http.RequestAbortedException();
    if (token.isEmpty) {
      throw const LlmRequestException(
        failure: LlmRequestFailure.unauthorized,
        message: 'ChatGPT sign-in is required.',
      );
    }
    final request = http.AbortableRequest(
      'GET',
      Uri.parse('https://api.openai.com/v1/models'),
      abortTrigger: abort.future,
    );
    request.followRedirects = false;
    request.headers['Authorization'] = 'Bearer $token';
    final response = await http.Response.fromStream(
      await connection.send(request),
    );
    if (response.statusCode != 200) {
      throw LlmRequestException(
        failure: switch (response.statusCode) {
          401 || 403 => LlmRequestFailure.unauthorized,
          429 => LlmRequestFailure.quotaExceeded,
          _ => LlmRequestFailure.unavailable,
        },
        message: 'Could not load available ChatGPT models.',
      );
    }
    final data = jsonDecode(response.body);
    if (data is! Map || data['models'] is! List) {
      throw const FormatException('Invalid model catalog');
    }
    final models = <AiModelOption>[];
    final seen = <String>{};
    for (final entry in data['models'] as List) {
      if (entry is! Map || entry['visibility'] != 'list') continue;
      final slug = entry['slug'];
      if (slug is! String || slug.isEmpty || !seen.add(slug)) continue;
      models.add(
        AiModelOption(
          id: slug,
          label: entry['display_name'] is String
              ? entry['display_name'] as String
              : slug,
        ),
      );
    }
    return models;
  }
}

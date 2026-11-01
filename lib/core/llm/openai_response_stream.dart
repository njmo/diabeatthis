import 'dart:async';
import 'dart:convert';

import 'llm_output_limit_exception.dart';
import 'local_llm_client.dart';
import 'openai_request_exception.dart';

/// Reads Responses API SSE events and accepts only a completed text response.
class OpenAiResponseStream {
  const OpenAiResponseStream();

  Future<String> read(
    Stream<List<int>> stream, {
    required Future<void> abortTrigger,
  }) async {
    final lines = StreamIterator(
      stream.transform(utf8.decoder).transform(const LineSplitter()),
    );
    unawaited(abortTrigger.then((_) => lines.cancel()));
    final deltas = StringBuffer();
    final data = <String>[];

    try {
      while (await lines.moveNext()) {
        final line = lines.current;
        if (line.isEmpty) {
          final text = _readEvent(data, deltas);
          data.clear();
          if (text != null) return text;
        } else if (line.startsWith('data:')) {
          final value = line.substring(5);
          data.add(value.startsWith(' ') ? value.substring(1) : value);
        }
      }
      final text = _readEvent(data, deltas);
      if (text != null) return text;
      throw const LlmRequestException(
        failure: LlmRequestFailure.unavailable,
        message: 'OpenAI response ended before completion.',
      );
    } on LlmOutputLimitException {
      rethrow;
    } on FormatException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.unavailable,
        message: 'OpenAI returned an invalid response.',
      );
    } finally {
      await lines.cancel();
    }
  }

  String? _readEvent(List<String> data, StringBuffer deltas) {
    if (data.isEmpty) return null;
    final payload = data.join('\n');
    if (payload == '[DONE]') return null;
    final event = jsonDecode(payload);
    if (event is! Map<String, dynamic>) {
      throw const FormatException('Invalid response event');
    }
    switch (event['type']) {
      case 'response.output_text.delta':
        final delta = event['delta'];
        if (delta is String) deltas.write(delta);
      case 'response.completed':
        final response = event['response'];
        if (response is! Map<String, dynamic> ||
            response['status'] != 'completed') {
          throw const FormatException('Invalid completion event');
        }
        final text = _outputText(response);
        if (text.trim().isEmpty) {
          throw const LlmRequestException(
            failure: LlmRequestFailure.unavailable,
            message: 'OpenAI returned no usable text.',
          );
        }
        return text;
      case 'response.incomplete':
        final response = event['response'];
        if (response is Map<String, dynamic>) {
          final details = response['incomplete_details'];
          if (details is Map && details['reason'] == 'max_output_tokens') {
            final partial = _outputText(response);
            throw LlmOutputLimitException(
              partial.isEmpty ? deltas.toString() : partial,
            );
          }
        }
        throw openAiRequestException();
      case 'response.failed':
        final response = event['response'];
        final error = response is Map ? response['error'] : null;
        throw openAiRequestException(code: _errorCode(error));
      case 'error':
        throw openAiRequestException(
          code: _errorCode(event['error']) ?? _errorCode(event),
        );
    }
    return null;
  }

  String _outputText(Map<String, dynamic> response) {
    final output = response['output'];
    if (output is! List) return '';
    final texts = <String>[];
    for (final item in output) {
      if (item is! Map || item['type'] != 'message') continue;
      final content = item['content'];
      if (content is! List) continue;
      for (final part in content) {
        if (part is Map && part['type'] == 'output_text') {
          final text = part['text'];
          if (text is String) texts.add(text);
        }
      }
    }
    return texts.join('\n');
  }

  String? _errorCode(Object? error) {
    if (error is! Map) return null;
    final code = error['code'];
    return code is String ? code : null;
  }
}

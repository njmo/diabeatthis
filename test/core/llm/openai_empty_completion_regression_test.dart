import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/core/llm/openai_response_stream.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const text = '{"schema_version":1,"status":"proposal"}';
  String event(Map<String, dynamic> value) => 'data: ${jsonEncode(value)}\n\n';

  test('recovers streamed text when completed output is empty', () async {
    final abort = Completer<void>();
    final stream =
        event({
          'type': 'response.output_text.delta',
          'delta': text.substring(0, 20),
        }) +
        event({
          'type': 'response.output_text.delta',
          'delta': text.substring(20),
        }) +
        event({
          'type': 'response.completed',
          'response': {'status': 'completed', 'output': []},
        });
    expect(
      await const OpenAiResponseStream().read(
        Stream.value(utf8.encode(stream)),
        abortTrigger: abort.future,
      ),
      text,
    );
    abort.complete();
  });

  test('does not recover deltas when final response is a refusal', () async {
    final abort = Completer<void>();
    final stream =
        event({'type': 'response.output_text.delta', 'delta': text}) +
        event({
          'type': 'response.completed',
          'response': {
            'status': 'completed',
            'output': [
              {
                'type': 'message',
                'content': [
                  {'type': 'refusal', 'refusal': 'Refused'},
                ],
              },
            ],
          },
        });
    await expectLater(
      const OpenAiResponseStream().read(
        Stream.value(utf8.encode(stream)),
        abortTrigger: abort.future,
      ),
      throwsA(isA<LlmRequestException>()),
    );
    abort.complete();
  });
}

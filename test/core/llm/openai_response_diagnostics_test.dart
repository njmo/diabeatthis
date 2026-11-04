import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/core/llm/openai_response_stream.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('captures completion payload before empty text rejection', () async {
    final payload = jsonEncode({
      'type': 'response.completed',
      'response': {
        'id': 'resp_diagnostic',
        'status': 'completed',
        'output': [
          {
            'type': 'message',
            'content': [
              {'type': 'refusal', 'refusal': 'Diagnostic refusal'},
            ],
          },
        ],
      },
    });
    final captured = <String>[];
    final abort = Completer<void>();
    final reader = OpenAiResponseStream(onRawEvent: captured.add);
    await expectLater(
      reader.read(
        Stream.value(utf8.encode('data: $payload\n\n')),
        abortTrigger: abort.future,
      ),
      throwsA(isA<LlmRequestException>()),
    );
    expect(captured, [payload]);
    abort.complete();
  });

  test('captures malformed event before JSON decoding fails', () async {
    final captured = <String>[];
    final abort = Completer<void>();
    await expectLater(
      OpenAiResponseStream(onRawEvent: captured.add).read(
        Stream.value(utf8.encode('data: invalid json\n\n')),
        abortTrigger: abort.future,
      ),
      throwsA(isA<LlmRequestException>()),
    );
    expect(captured, ['invalid json']);
    abort.complete();
  });
}

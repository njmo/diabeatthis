import 'package:diabeatthis/common/ai/ai_response_diagnostics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled raw response diagnostics emit no private payload', () {
    final original = debugPrint;
    final output = <String?>[];
    debugPrint = (message, {wrapWidth}) => output.add(message);
    addTearDown(() => debugPrint = original);
    printAiResponseDiagnostic(
      tag: 'AI',
      requestId: 'request',
      stage: 'response',
      response: 'PRIVATE_MEAL_CONTENT',
      enabled: false,
    );
    expect(output, isEmpty);
    printAiResponseDiagnostic(
      tag: 'AI',
      requestId: 'request',
      stage: 'response',
      response: 'debug-only payload',
      enabled: true,
    );
    expect(output.join(), contains('debug-only payload'));
  });
}

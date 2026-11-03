import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// A strict boundary stub: unexpected, missing and duplicate reads all fail.
/// Unlike a default empty mock, it cannot silently hide a new dependency.
class ScriptedRead<T> {
  final String name;
  final List<({List<Object?> arguments, FutureOr<T> Function() respond})> steps;
  final List<List<Object?>> calls = [];
  int unexpectedCalls = 0;

  ScriptedRead(this.name, this.steps);

  Future<T> call(List<Object?> arguments) async {
    final index = calls.length;
    calls.add(List.unmodifiable(arguments));
    if (index >= steps.length) {
      unexpectedCalls++;
      throw StateError('Unexpected $name read: $arguments');
    }
    final step = steps[index];
    if (!equals(step.arguments).matches(arguments, {})) {
      unexpectedCalls++;
      throw StateError('$name expected ${step.arguments}, received $arguments');
    }
    return await step.respond();
  }

  void verifyComplete() {
    expect(unexpectedCalls, 0, reason: '$name made an unexpected read: $calls');
    expect(
      calls.length,
      steps.length,
      reason: '$name did not consume its script',
    );
  }
}

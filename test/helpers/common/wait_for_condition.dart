import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Waits for observable progress, independent of the application clock.
Future<void> waitForCondition(
  FutureOr<bool> Function() condition, {
  required String description,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final elapsed = Stopwatch()..start();
  while (!await condition()) {
    if (elapsed.elapsed >= timeout) {
      fail('Timed out waiting for $description');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

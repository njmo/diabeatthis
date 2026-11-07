import 'dart:async';

import 'package:diabeatthis/common/async/coalescing_async_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'signals during work run again immediately and never concurrently',
    () async {
      final pump = CoalescingAsyncAction();
      final first = Completer<void>();
      var calls = 0, active = 0, maxActive = 0;
      Future<void> action() async {
        calls++;
        active++;
        if (active > maxActive) maxActive = active;
        if (calls == 1) await first.future;
        active--;
      }

      final running = pump(action);
      await pump(action);
      await pump(action);
      expect(calls, 1);
      first.complete();
      await running;
      expect(calls, 2);
      expect(maxActive, 1);
    },
  );
  test('disposal prevents queued follow-up work', () async {
    final pump = CoalescingAsyncAction();
    final first = Completer<void>();
    var calls = 0;
    Future<void> action() async {
      calls++;
      await first.future;
    }

    final running = pump(action);
    await pump(action);
    pump.dispose();
    first.complete();
    await running;
    expect(calls, 1);
  });
}

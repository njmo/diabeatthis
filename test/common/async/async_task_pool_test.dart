import 'dart:async';

import 'package:diabeatthis/common/async/async_task_pool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'limits running work and releases slots after success and failure',
    () async {
      final pool = AsyncTaskPool(2);
      final gates = List.generate(3, (_) => Completer<void>());
      final started = <int>[];
      final futures = [
        for (var i = 0; i < 3; i++)
          pool.run(() async {
            started.add(i);
            await gates[i].future;
            if (i == 0) throw StateError('failed');
            return i;
          }),
      ];
      final failure = expectLater(futures[0], throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(started, [0, 1]);
      gates[0].complete();
      await failure;
      await Future<void>.delayed(Duration.zero);
      expect(started, [0, 1, 2]);
      gates[1].complete();
      gates[2].complete();
      expect(await Future.wait(futures.skip(1)), [1, 2]);
      expect(await pool.run(() async => 4), 4);
    },
  );
}

import 'dart:async';

import 'package:diabeatthis/common/refresh/visible_app_refresh_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'polls immediately and periodically, pauses, and deduplicates refreshes',
    () {
      fakeAsync((time) {
        final pending = <Completer<int>>[];
        final values = <int>[];
        final controller = VisibleAppRefreshController<int>(
          fetch: () {
            final request = Completer<int>();
            pending.add(request);
            return request.future;
          },
          onData: values.add,
          onError: (_) => fail('Unexpected failure'),
        );
        controller.start();
        controller.refreshNow();
        expect(pending, hasLength(1));
        pending[0].complete(1);
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 29));
        expect(pending, hasLength(1));
        time.elapse(const Duration(seconds: 1));
        expect(pending, hasLength(2));
        controller.stop();
        pending[1].complete(2);
        time.flushMicrotasks();
        time.elapse(const Duration(minutes: 2));
        expect(values, [1]);
        expect(pending, hasLength(2));
        controller.start();
        expect(pending, hasLength(3));
        pending[2].complete(3);
        time.flushMicrotasks();
        expect(values, [1, 3]);
        controller.dispose();
        time.elapse(const Duration(minutes: 2));
        expect(pending, hasLength(3));
      });
    },
  );
  test(
    'resume during an in-flight request discards it and fetches a new session',
    () {
      fakeAsync((time) {
        final pending = <Completer<int>>[];
        final values = <int>[];
        final controller = VisibleAppRefreshController<int>(
          fetch: () {
            final request = Completer<int>();
            pending.add(request);
            return request.future;
          },
          onData: values.add,
          onError: (_) {},
        );
        controller.start();
        controller.stop();
        controller.start();
        expect(pending, hasLength(1));
        pending.first.complete(1);
        time.flushMicrotasks();
        expect(values, isEmpty);
        expect(pending, hasLength(2));
        pending.last.complete(2);
        time.flushMicrotasks();
        expect(values, [2]);
        controller.dispose();
      });
    },
  );
  test('a failed refresh retries without replacing previous data', () {
    fakeAsync((time) {
      var attempts = 0;
      var failures = 0;
      final values = <int>[];
      final controller = VisibleAppRefreshController<int>(
        fetch: () async {
          attempts++;
          if (attempts == 2) throw StateError('Offline');
          return attempts;
        },
        onData: values.add,
        onError: (_) => failures++,
      );
      controller.start();
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 30));
      time.flushMicrotasks();
      expect(values, [1]);
      expect(failures, 1);
      time.elapse(const Duration(seconds: 30));
      time.flushMicrotasks();
      expect(values, [1, 3]);
      controller.dispose();
    });
  });
}

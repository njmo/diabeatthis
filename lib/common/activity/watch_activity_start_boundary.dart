import 'dart:async';

import 'package:clock/clock.dart';

/// Re-evaluates open sessions at their start boundary without database writes.
/// Cancelling the subscription releases both the database listener and timer.
Stream<T?> watchActivityStartBoundary<T>({
  required Stream<List<T>> source,
  required DateTime Function(T) startedAt,
}) {
  late StreamController<T?> output;
  StreamSubscription<List<T>>? subscription;
  Timer? timer;
  var rows = <T>[];
  var paused = false;
  void emit() {
    timer?.cancel();
    if (paused || output.isClosed) return;
    final now = clock.now();
    T? active;
    DateTime? next;
    for (final row in rows) {
      final start = startedAt(row);
      if (!start.isAfter(now)) {
        active ??= row;
      } else if (next == null || start.isBefore(next)) {
        next = start;
      }
    }
    output.add(active);
    if (next != null) timer = Timer(next.difference(now), emit);
  }

  output = StreamController<T?>(
    sync: true,
    onListen: () {
      subscription = source.listen(
        (value) {
          rows = value;
          emit();
        },
        onError: (Object error, StackTrace stack) {
          timer?.cancel();
          output.addError(error, stack);
        },
        onDone: () {
          timer?.cancel();
          subscription = null;
          output.close();
        },
      );
    },
    onPause: () {
      paused = true;
      timer?.cancel();
    },
    onResume: () {
      paused = false;
      emit();
    },
    onCancel: () async {
      timer?.cancel();
      await subscription?.cancel();
    },
  );
  return output.stream;
}

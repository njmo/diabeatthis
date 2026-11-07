/// Keeps at most one action in flight. A signal received while it runs causes
/// an immediate follow-up, without waiting for an external polling timer.
class CoalescingAsyncAction {
  bool running = false;
  bool again = false;
  bool disposed = false;

  Future<void> call(Future<void> Function() action) async {
    if (disposed) return;
    if (running) {
      again = true;
      return;
    }
    running = true;
    try {
      do {
        again = false;
        await action();
      } while (again && !disposed);
    } finally {
      running = false;
    }
  }

  void dispose() {
    disposed = true;
    again = false;
  }
}

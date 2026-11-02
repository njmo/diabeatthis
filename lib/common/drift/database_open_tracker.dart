import 'package:drift/drift.dart';

/// Tracks use of this connection, including clients joining an open isolate.
class DatabaseOpenTracker extends QueryInterceptor {
  bool hasOpened = false;

  @override
  Future<bool> ensureOpen(
    QueryExecutor executor,
    QueryExecutorUser user,
  ) async {
    final opened = await executor.ensureOpen(user);
    if (opened) hasOpened = true;
    return opened;
  }
}

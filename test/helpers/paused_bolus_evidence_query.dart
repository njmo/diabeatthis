import 'dart:async';

import 'package:drift/drift.dart';

class PausedBolusEvidenceQuery extends QueryInterceptor {
  PausedBolusEvidenceQuery(this.stage);

  final String stage;
  final reached = Completer<void>();
  final resume = Completer<void>();
  bool armed = false;
  bool manualWritten = false;

  Future<void> pause(String point) async {
    if (!armed || stage != point || reached.isCompleted) return;
    reached.complete();
    await resume.future;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runSelect(statement, args);
    if (statement.startsWith('SELECT') && statement.contains('manual_bolus')) {
      await pause('read');
    }
    return result;
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runInsert(statement, args);
    if (statement.contains('manual_bolus')) {
      manualWritten = true;
      await pause('write');
    }
    return result;
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await inner.send();
    if (manualWritten) await pause('commit');
  }
}

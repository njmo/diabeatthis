import 'dart:async';

import 'package:drift/drift.dart';

class PausedCarbohydrateEvidenceQuery extends QueryInterceptor {
  PausedCarbohydrateEvidenceQuery(this.stage);

  final String stage;
  final reached = Completer<void>();
  final resume = Completer<void>();
  bool componentWritten = false;
  final roots = <TransactionExecutor>{};

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    final transaction = parent.beginTransaction();
    if (parent is! TransactionExecutor) roots.add(transaction);
    return transaction;
  }

  Future<void> pause(String point) async {
    if (stage != point || reached.isCompleted) return;
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
    if (statement.contains('manual_bolus')) await pause('read');
    return result;
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runUpdate(statement, args);
    if (statement.contains('carbohydrate_component') &&
        args.any((value) => value is String && value.contains('createdAt'))) {
      componentWritten = true;
      await pause('write');
    }
    return result;
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await inner.send();
    if (componentWritten && roots.contains(inner)) await pause('commit');
  }
}

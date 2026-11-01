import 'dart:async';

import 'package:drift/drift.dart';

class PausedIngredientWrite extends QueryInterceptor {
  final reached = Completer<void>();
  final resume = Completer<void>();

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runSelect(statement, args);
    if (!reached.isCompleted &&
        RegExp(
          r'^INSERT INTO "?ingredient"?\s*\(',
          caseSensitive: false,
        ).hasMatch(statement)) {
      reached.complete();
      await resume.future;
    }
    return result;
  }
}

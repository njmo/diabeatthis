import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/drift/database_impl.dart';
import 'database_backup_result.dart';
import 'database_backup_scope.dart';

class DatabaseBackupService {
  DatabaseBackupService(this._db);

  static const int formatVersion = 1;

  static const Set<String> coreTableNames = {
    'ingredient',
    'portion',
    'ingredient_portions',
    'activity',
    'meal_template',
    'meal_template_ingredients',
  };

  final DatabaseImpl _db;

  Future<File> exportToFile(DatabaseBackupScope scope) async {
    final payload = await exportToJson(scope);
    final dir = await getTemporaryDirectory();
    final nowToken = clock.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'diabeatthis-db-${scope.fileToken}-$nowToken.json';
    final file = File(p.join(dir.path, fileName));

    const encoder = JsonEncoder.withIndent('  ');
    return file.writeAsString(encoder.convert(payload), flush: true);
  }

  Future<Map<String, Object?>> exportToJson(DatabaseBackupScope scope) async {
    final tableNames = _tableNamesForScope(scope);
    final tables = <String, List<Map<String, Object?>>>{};
    var rowCount = 0;

    for (final tableName in tableNames) {
      final columns = await _insertableColumns(tableName);
      final rows = await _selectRows(tableName, columns);
      tables[tableName] = rows;
      rowCount += rows.length;
    }

    return {
      'formatVersion': formatVersion,
      'schemaVersion': _db.schemaVersion,
      'scope': scope.fileToken,
      'exportedAt': clock.now().toIso8601String(),
      'rowCount': rowCount,
      'tables': tables,
    };
  }

  Future<DatabaseBackupResult> importFromFile(File file) async {
    final payload = jsonDecode(await file.readAsString());
    if (payload is! Map<String, Object?>) {
      throw const FormatException('Database backup must be a JSON object');
    }

    return importFromJson(payload);
  }

  Future<DatabaseBackupResult> importFromJson(
    Map<String, Object?> payload,
  ) async {
    final version = payload['formatVersion'];
    if (version != formatVersion) {
      throw FormatException('Unsupported database backup version: $version');
    }

    final scopeValue = payload['scope'];
    if (scopeValue is! String) {
      throw const FormatException('Database backup scope is missing');
    }

    final scope = DatabaseBackupScope.fromJson(scopeValue);
    final tablesValue = payload['tables'];
    if (tablesValue is! Map<String, Object?>) {
      throw const FormatException('Database backup tables are missing');
    }

    final tableRows = _parseTableRows(tablesValue);
    final allowedTables = _tableNamesForScope(scope).toSet();
    final unsupportedTables = tableRows.keys.where(
      (tableName) => !allowedTables.contains(tableName),
    );
    final unsupportedTable = unsupportedTables.isEmpty
        ? null
        : unsupportedTables.first;
    if (unsupportedTable != null) {
      throw FormatException(
        'Table $unsupportedTable is not allowed for ${scope.fileToken} backup',
      );
    }

    var rowCount = 0;
    await _withForeignKeysDisabled(() async {
      await _clearForImport();

      for (final tableName in _tableNamesForScope(scope)) {
        final rows = tableRows[tableName] ?? const [];
        for (final row in rows) {
          await _insertRow(tableName, row);
        }
        rowCount += rows.length;
      }
    });

    return DatabaseBackupResult(
      scope: scope,
      tableCount: tableRows.length,
      rowCount: rowCount,
    );
  }

  Future<void> clearHistoryKeepingCoreData() async {
    await _withForeignKeysDisabled(() async {
      await _deleteTables(
        _allTableNames.where(
          (tableName) => !coreTableNames.contains(tableName),
        ),
      );
    });
  }

  List<String> _tableNamesForScope(DatabaseBackupScope scope) {
    return switch (scope) {
      DatabaseBackupScope.core =>
        _allTableNames.where(coreTableNames.contains).toList(growable: false),
      DatabaseBackupScope.full => _allTableNames,
    };
  }

  List<String> get _allTableNames {
    return _db.allTables
        .map((table) => table.actualTableName)
        .toList(growable: false);
  }

  Future<void> _clearForImport() async {
    await _deleteTables(_allTableNames);
  }

  Future<void> _deleteTables(Iterable<String> tableNames) async {
    for (final tableName in tableNames) {
      await _db.customStatement('DELETE FROM ${_quoteIdentifier(tableName)}');
    }
  }

  Future<void> _withForeignKeysDisabled(Future<void> Function() action) async {
    await _db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await _db.transaction(action);
    } finally {
      await _db.customStatement('PRAGMA foreign_keys = ON');
    }
  }

  Future<List<String>> _insertableColumns(String tableName) async {
    final rows = await _db
        .customSelect('PRAGMA table_xinfo(${_quoteString(tableName)})')
        .get();

    return rows
        .where((row) => row.data['hidden'] == 0)
        .map((row) => row.data['name'])
        .whereType<String>()
        .toList(growable: false);
  }

  Future<List<Map<String, Object?>>> _selectRows(
    String tableName,
    List<String> columns,
  ) async {
    final selectedColumns = columns.map(_quoteIdentifier).join(', ');
    final rows = await _db
        .customSelect(
          'SELECT $selectedColumns FROM ${_quoteIdentifier(tableName)}',
        )
        .get();

    return rows
        .map(
          (row) => {
            for (final column in columns) column: _jsonValue(row.data[column]),
          },
        )
        .toList(growable: false);
  }

  Future<void> _insertRow(String tableName, Map<String, Object?> row) async {
    if (row.isEmpty) return;

    final columns = row.keys.toList(growable: false);
    final sqlColumns = columns.map(_quoteIdentifier).join(', ');
    final placeholders = List.filled(columns.length, '?').join(', ');
    final variables = columns
        .map((column) => _variableForValue(row[column]))
        .toList(growable: false);

    await _db.customInsert(
      'INSERT INTO ${_quoteIdentifier(tableName)} ($sqlColumns) '
      'VALUES ($placeholders)',
      variables: variables,
    );
  }

  Map<String, List<Map<String, Object?>>> _parseTableRows(
    Map<String, Object?> tables,
  ) {
    return {
      for (final entry in tables.entries)
        entry.key: _parseRows(entry.key, entry.value),
    };
  }

  List<Map<String, Object?>> _parseRows(String tableName, Object? value) {
    if (value is! List<Object?>) {
      throw FormatException('Rows for $tableName must be a JSON array');
    }

    return value
        .map((row) {
          if (row is! Map<String, Object?>) {
            throw FormatException('Rows for $tableName must be JSON objects');
          }

          return row;
        })
        .toList(growable: false);
  }

  Object? _jsonValue(Object? value) {
    if (value is Uint8List) return base64Encode(value);
    return value;
  }

  Variable _variableForValue(Object? value) {
    if (value is bool) return Variable<bool>(value);
    if (value is int) return Variable<int>(value);
    if (value is double) return Variable<double>(value);
    if (value is String) return Variable<String>(value);
    if (value == null) return const Variable<Object>(null);

    throw FormatException('Unsupported database backup value: $value');
  }

  String _quoteIdentifier(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }

  String _quoteString(String value) {
    return "'${value.replaceAll("'", "''")}'";
  }
}

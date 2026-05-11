import 'database_backup_scope.dart';

class DatabaseBackupResult {
  const DatabaseBackupResult({
    required this.scope,
    required this.tableCount,
    required this.rowCount,
  });

  final DatabaseBackupScope scope;
  final int tableCount;
  final int rowCount;
}

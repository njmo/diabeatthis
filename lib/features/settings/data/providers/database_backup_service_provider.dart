import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../database_backup_service.dart';

final databaseBackupServiceProvider = Provider<DatabaseBackupService>((ref) {
  final db = ref.watch(databaseProvider);
  return DatabaseBackupService(db);
});

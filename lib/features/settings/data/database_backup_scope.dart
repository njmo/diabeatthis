enum DatabaseBackupScope {
  core,
  full;

  String get fileToken => switch (this) {
    DatabaseBackupScope.core => 'core',
    DatabaseBackupScope.full => 'full',
  };

  static DatabaseBackupScope fromJson(String value) {
    return switch (value) {
      'core' => DatabaseBackupScope.core,
      'full' => DatabaseBackupScope.full,
      _ => throw FormatException('Unknown database backup scope: $value'),
    };
  }
}

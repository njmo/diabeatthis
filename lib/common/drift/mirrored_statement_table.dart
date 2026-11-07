import '../family_sync/family_mirror_integration.dart';

/// Raw domain writes need the same shared Drift invalidation as generated DAOs.
/// Internal sync bookkeeping is excluded to avoid feedback loops.
String? mirroredStatementTable(String statement) {
  final match = RegExp(
    r'^\s*(?:INSERT(?:\s+OR\s+\w+)?\s+INTO|REPLACE\s+INTO|UPDATE(?:\s+OR\s+\w+)?|DELETE\s+FROM)\s+["`\[]?([a-zA-Z_][a-zA-Z0-9_]*)',
    caseSensitive: false,
  ).firstMatch(statement);
  final name = match?.group(1)?.toLowerCase();
  return name != null &&
          familyMirrorIntegrations.any((entry) => entry.table == name)
      ? name
      : null;
}

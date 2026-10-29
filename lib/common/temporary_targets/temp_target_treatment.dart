/// Shared parsing for verification of Nightscout temporary target treatments.
class TempTargetTreatment {
  const TempTargetTreatment._();

  static DateTime? startedAt(Map<String, dynamic> treatment) {
    final created = DateTime.tryParse(
      treatment['created_at']?.toString() ?? '',
    );
    if (created != null) return created;
    final date = treatment['date'];
    return date is num
        ? DateTime.fromMillisecondsSinceEpoch(date.round(), isUtc: true)
        : null;
  }

  static Duration duration(Map<String, dynamic> treatment) {
    final milliseconds = treatment['durationInMilliseconds'];
    final minutes = treatment['duration'];
    return Duration(
      milliseconds: milliseconds is num
          ? milliseconds.round()
          : minutes is num
          ? (minutes * Duration.millisecondsPerMinute).round()
          : 0,
    );
  }
}

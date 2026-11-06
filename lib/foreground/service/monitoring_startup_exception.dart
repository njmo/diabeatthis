class MonitoringStartupException implements Exception {
  const MonitoringStartupException(this.cause);
  final Object cause;
  @override
  String toString() =>
      'Monitoring startup did not complete (${cause.runtimeType}).';
}

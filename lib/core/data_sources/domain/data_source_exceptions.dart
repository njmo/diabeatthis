class UnsupportedDataSourceException implements Exception {
  const UnsupportedDataSourceException(this.message);

  final String message;

  @override
  String toString() => 'UnsupportedDataSourceException: $message';
}

class LocalHistoryUnavailableException extends UnsupportedDataSourceException {
  const LocalHistoryUnavailableException()
    : super('Local history source is not implemented yet');
}

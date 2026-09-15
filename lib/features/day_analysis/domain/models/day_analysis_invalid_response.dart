/// Keeps rejected output in memory for explicit inspection, never in error logs.
class DayAnalysisInvalidResponse extends FormatException {
  final String response;
  final bool tokenLimitReached;

  const DayAnalysisInvalidResponse({
    required this.response,
    this.tokenLimitReached = false,
    required String reason,
  }) : super(reason);
}

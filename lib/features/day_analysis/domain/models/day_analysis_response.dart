/// Exact text request and raw model output, independent of the transport.
class DayAnalysisResponse {
  final String prompt;
  final String text;
  const DayAnalysisResponse({required this.prompt, required this.text});
}

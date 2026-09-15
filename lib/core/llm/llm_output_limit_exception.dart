/// Partial output is available for explicit preview but omitted from logs.
class LlmOutputLimitException extends FormatException {
  final String response;

  const LlmOutputLimitException(this.response)
    : super('Model output token limit reached');
}

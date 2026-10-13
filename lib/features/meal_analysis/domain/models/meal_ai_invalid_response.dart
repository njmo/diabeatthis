class MealAiInvalidResponse implements Exception {
  final String response;
  final bool tokenLimitReached;
  const MealAiInvalidResponse(this.response, {this.tokenLimitReached = false});
}

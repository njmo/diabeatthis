enum MealPhotoClarificationReason {
  ambiguousMenuItem,
  unreadableMenu,
  missingMenu,
  conflictingEvidence,
}

/// A successful recognition request may need more evidence before any meal can
/// be proposed. This is distinct from transport errors or malformed responses.
class MealPhotoClarificationRequired implements Exception {
  MealPhotoClarificationRequired({
    required this.reason,
    required List<String> questions,
    required this.rawResponse,
  }) : questions = List.unmodifiable(questions);
  final MealPhotoClarificationReason reason;
  final List<String> questions;
  final String rawResponse;
}

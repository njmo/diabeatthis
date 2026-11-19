enum FamilyQuestionReplyStatus {
  unanswered,
  failed,
  pending,
  unknown,
  confirmed,
}

/// The child's answer state; another family member never answers on its behalf.
class FamilyQuestionReplyState {
  const FamilyQuestionReplyState(this.status, {this.replyId});

  final FamilyQuestionReplyStatus status;
  final String? replyId;

  /// An ambiguous send must be resolved before creating another operation.
  bool get blocksNewAnswer => switch (status) {
    FamilyQuestionReplyStatus.confirmed ||
    FamilyQuestionReplyStatus.pending ||
    FamilyQuestionReplyStatus.unknown => true,
    FamilyQuestionReplyStatus.unanswered ||
    FamilyQuestionReplyStatus.failed => false,
  };
}

/// Local outbox states that have not been attempted yet.
const familyReplyUnsentErrors = {'awaiting-ticket', 'needs-ticket'};

/// Classifies one stored outbox operation. An unsigned operation (no ticket)
/// was never sent, so any terminal error on it is a definite failure. A signed
/// operation is never proven unsent by a rejection: an earlier request with
/// the same ID (e.g. held in another isolate) may still commit afterwards, so
/// every terminal error on it stays ambiguous.
FamilyQuestionReplyStatus familyReplyOperationStatus({
  required String? error,
  required bool signed,
}) {
  if (error == null || familyReplyUnsentErrors.contains(error)) {
    return FamilyQuestionReplyStatus.pending;
  }
  return signed
      ? FamilyQuestionReplyStatus.unknown
      : FamilyQuestionReplyStatus.failed;
}

/// Status of one answer row in the projected history/queue shape.
///
/// Rows projected with `operationSigned` (raw outbox state) are classified
/// exactly. Older projections only carry `delivery`/`sendOutcomeUnknown`.
FamilyQuestionReplyStatus familyAnswerRowStatus(Map<dynamic, dynamic> row) {
  if (row['redactedOutcome'] == true) return FamilyQuestionReplyStatus.unknown;
  if (row.containsKey('operationSigned')) {
    final error = row['operationError'];
    return familyReplyOperationStatus(
      error: error is String ? error : null,
      signed: row['operationSigned'] == true,
    );
  }
  if (row['sendOutcomeUnknown'] == true) {
    return FamilyQuestionReplyStatus.unknown;
  }
  return switch (row['delivery']) {
    null => FamilyQuestionReplyStatus.confirmed,
    'pending' => FamilyQuestionReplyStatus.pending,
    'failed' => FamilyQuestionReplyStatus.failed,
    _ => FamilyQuestionReplyStatus.unknown,
  };
}

/// Pure reply decision shared by UI, application, data and background code.
///
/// [messages] are already admitted rows of one scope (history, local queue
/// and redacted outcome markers). Only answers authored by [childUid] count;
/// an empty [childUid] never authorizes or completes an answer.
///
/// Redacted outcome markers are the child's own operations whose body was
/// purged. A marker that kept `outcomeKind: 'answer'` and `replyTo` blocks only
/// that question. A legacy marker without `outcomeKind` cannot be associated,
/// so it conservatively blocks the questions in the same input (callers pass
/// one target) that were sent no later than the marker.
Map<String, FamilyQuestionReplyState> familyQuestionReplyStates(
  List<Map<String, dynamic>> messages, {
  required String childUid,
}) {
  final questions = <String, Map<String, dynamic>>{
    for (final message in messages)
      if (message['kind'] == 'question' &&
          message['id'] is String &&
          (message['id'] as String).isNotEmpty)
        message['id'] as String: message,
  };
  final states = <String, FamilyQuestionReplyState>{
    for (final id in questions.keys)
      id: const FamilyQuestionReplyState(FamilyQuestionReplyStatus.unanswered),
  };
  if (childUid.isEmpty) return Map.unmodifiable(states);

  void offer(String parent, FamilyQuestionReplyState candidate) {
    final previous = states[parent]!;
    // Stable across pagination, cache merges and different input ordering.
    if (candidate.status.index > previous.status.index ||
        candidate.status == previous.status &&
            candidate.replyId!.compareTo(previous.replyId ?? '') > 0) {
      states[parent] = candidate;
    }
  }

  for (final message in messages) {
    final id = message['id'];
    if (message['senderUid'] != childUid || id is! String || id.isEmpty) {
      continue;
    }
    if (message['redactedOutcome'] == true) {
      final kind = message['outcomeKind'];
      final parent = message['replyTo'];
      if (kind == 'answer' && states.containsKey(parent)) {
        offer(
          parent as String,
          FamilyQuestionReplyState(
            FamilyQuestionReplyStatus.unknown,
            replyId: id,
          ),
        );
      } else if (kind == null) {
        final at = message['sentAt'];
        for (final entry in questions.entries) {
          final asked = entry.value['sentAt'];
          if (at is int && asked is int && asked > at) continue;
          offer(
            entry.key,
            FamilyQuestionReplyState(
              FamilyQuestionReplyStatus.unknown,
              replyId: id,
            ),
          );
        }
      }
      continue;
    }
    final parent = message['replyTo'];
    if (message['kind'] != 'answer' || !states.containsKey(parent)) continue;
    offer(
      parent as String,
      FamilyQuestionReplyState(familyAnswerRowStatus(message), replyId: id),
    );
  }
  return Map.unmodifiable(states);
}

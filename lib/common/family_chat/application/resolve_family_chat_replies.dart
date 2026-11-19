import '../domain/family_question_reply_state.dart';

/// Resolves reply context without hiding or duplicating any message.
class ResolveFamilyChatReplies {
  const ResolveFamilyChatReplies();

  /// Input is the already admitted history and local queue for one scope.
  /// Selection provenance stays independent of successful delivery.
  Map<String, FamilyQuestionReplyState> questionStates(
    List<Map<String, dynamic>> messages, {
    required String childUid,
  }) => familyQuestionReplyStates(messages, childUid: childUid);

  Map<String, ({String questionId, bool selected})> call(
    List<Map<String, dynamic>> messages,
  ) {
    final questions = {
      for (final message in messages)
        if (message['kind'] == 'question') message['id'] as String: message,
    };
    return Map.unmodifiable({
      for (final message in messages)
        if (message['kind'] == 'answer' &&
            questions.containsKey(message['replyTo']))
          message['id'] as String: (
            questionId: message['replyTo'] as String,
            selected: _selected(questions[message['replyTo']]!, message),
          ),
    });
  }

  bool _selected(Map question, Map reply) {
    final index = reply['answerIndex'];
    final answers = question['answers'] as List? ?? [];
    return index is int &&
        index >= 0 &&
        index < answers.length &&
        answers[index] is String &&
        (answers[index] as String).trim() == (reply['text'] as String).trim();
  }
}

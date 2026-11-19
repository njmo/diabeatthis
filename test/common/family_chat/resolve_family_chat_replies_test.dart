import 'package:diabeatthis/common/family_chat/application/resolve_family_chat_replies.dart';
import 'package:diabeatthis/common/family_chat/domain/family_question_reply_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolve = ResolveFamilyChatReplies();
  final question = {
    'id': 'q',
    'kind': 'question',
    'answers': [' Mam ', 'Nie mam'],
  };
  Map<String, dynamic> answer(
    String id,
    String text, {
    String? delivery,
    int? answerIndex,
  }) => {
    'id': id,
    'kind': 'answer',
    'replyTo': 'q',
    'text': text,
    if (delivery != null) 'delivery': delivery,
    if (answerIndex != null) 'answerIndex': answerIndex,
  };
  test('identifies a selected suggestion separately from a written reply', () {
    final result = resolve([
      question,
      answer('a', 'Mam', answerIndex: 0),
      answer('b', 'Mam'),
      answer('c', 'Mam', answerIndex: 1),
    ]);
    expect(result['a'], (questionId: 'q', selected: true));
    expect(result['b'], (questionId: 'q', selected: false));
    expect(result['c'], (questionId: 'q', selected: false));
    expect(resolve([answer('a', 'Mam')]), isEmpty);
    expect(
      resolve([
        {'id': 'q', 'kind': 'lowTreatment'},
        answer('a', 'Mam'),
      ]),
      isEmpty,
    );
  });
  test(
    'pending and failed selected replies retain their own card and status',
    () {
      final result = resolve([
        question,
        answer('pending', 'Mam', delivery: 'pending', answerIndex: 0),
        answer('failed', 'Mam', delivery: 'failed', answerIndex: 0),
      ]);
      expect(result.keys, ['pending', 'failed']);
      expect(result.values.every((value) => value.selected), true);
    },
  );

  group('child question state', () {
    Map<String, dynamic> reply(
      String id, {
      String? delivery,
      String sender = 'child',
      bool unknown = false,
    }) => {
      ...answer(id, 'Mam', delivery: delivery, answerIndex: 0),
      'senderUid': sender,
      if (unknown) 'sendOutcomeUnknown': true,
    };

    FamilyQuestionReplyState state(List<Map<String, dynamic>> replies) =>
        resolve.questionStates([question, ...replies], childUid: 'child')['q']!;

    test('only an answer authored by the child counts', () {
      final rows = [
        reply('caregiver', sender: 'caregiver'),
        {...reply('missing'), 'senderUid': null},
        {...reply('malformed'), 'senderUid': 123},
        {...reply('text'), 'kind': 'text'},
        {...reply('other'), 'replyTo': 'other-question'},
      ];
      expect(state(rows).status, FamilyQuestionReplyStatus.unanswered);
      expect(state(rows).blocksNewAnswer, false);
      expect(
        resolve.questionStates([
          question,
          reply('own'),
        ], childUid: '')['q']!.status,
        FamilyQuestionReplyStatus.unanswered,
      );
    });

    test(
      'failed permits a new answer; pending and unknown prevent duplicates',
      () {
        expect(
          state([reply('failed', delivery: 'failed')]).blocksNewAnswer,
          false,
        );
        expect(
          state([reply('pending', delivery: 'pending')]).status,
          FamilyQuestionReplyStatus.pending,
        );
        expect(
          state([reply('pending', delivery: 'pending')]).blocksNewAnswer,
          true,
        );
        final uncertain = state([
          reply('failed', delivery: 'failed'),
          reply('unknown', delivery: 'failed', unknown: true),
        ]);
        expect(uncertain.status, FamilyQuestionReplyStatus.unknown);
        expect(uncertain.blocksNewAnswer, true);
        expect(uncertain.replyId, 'unknown');
      },
    );

    test(
      'an unsupported delivery state is ambiguous rather than confirmed',
      () {
        expect(
          state([reply('future', delivery: 'unrecognized')]).status,
          FamilyQuestionReplyStatus.unknown,
        );
      },
    );

    test(
      'confirmed own answer wins regardless of order or later foreign reply',
      () {
        final candidates = [
          reply('confirmed'),
          reply('foreign', sender: 'caregiver'),
          reply('failed', delivery: 'failed'),
          reply('pending', delivery: 'pending'),
          reply('unknown', delivery: 'failed', unknown: true),
        ];
        for (var offset = 0; offset < candidates.length; offset++) {
          final rotated = [
            ...candidates.skip(offset),
            ...candidates.take(offset),
          ];
          for (final rows in [rotated, rotated.reversed.toList()]) {
            final result = state(rows);
            expect(result.status, FamilyQuestionReplyStatus.confirmed);
            expect(result.replyId, 'confirmed');
            expect(result.blocksNewAnswer, true);
          }
        }
      },
    );

    test('ties have a stable identity without relying on message order', () {
      expect(state([reply('a'), reply('z')]).replyId, 'z');
      expect(state([reply('z'), reply('a')]).replyId, 'z');
    });

    test('selection provenance does not determine confirmed delivery', () {
      final mismatched = {...reply('written'), 'answerIndex': 1};
      expect(state([mismatched]).status, FamilyQuestionReplyStatus.confirmed);
      expect(resolve([question, mismatched])['written']!.selected, false);
      expect(
        state([reply('pending', delivery: 'pending')]).status,
        FamilyQuestionReplyStatus.pending,
      );
    });

    test(
      'clinical requests and unloaded questions remain outside the projection',
      () {
        expect(
          resolve.questionStates([
            {...question, 'kind': 'lowTreatment'},
            reply('answer'),
          ], childUid: 'child'),
          isEmpty,
        );
        expect(
          resolve.questionStates([reply('answer')], childUid: 'child'),
          isEmpty,
        );
        final result = resolve.questionStates([question], childUid: 'child');
        expect(() => result.clear(), throwsUnsupportedError);
      },
    );
  });

  group('shared operation and marker policy', () {
    test('stored operation errors are classified without guessing', () {
      FamilyQuestionReplyStatus status(String? error, {bool signed = true}) =>
          familyReplyOperationStatus(error: error, signed: signed);
      expect(status(null), FamilyQuestionReplyStatus.pending);
      expect(status('awaiting-ticket'), FamilyQuestionReplyStatus.pending);
      expect(status('needs-ticket'), FamilyQuestionReplyStatus.pending);
      for (final ambiguous in [
        'send-outcome-unknown',
        'expired',
        'already-exists',
        'failed-precondition',
        'cancelled',
        'internal',
        // A same-ID request held elsewhere may still commit after these.
        'not-found',
        'invalid-argument',
        'permission-denied',
      ]) {
        expect(
          status(ambiguous),
          FamilyQuestionReplyStatus.unknown,
          reason: ambiguous,
        );
      }
      // Never signed, so never reached the server.
      expect(
        status('expired', signed: false),
        FamilyQuestionReplyStatus.failed,
      );
    });

    final question = {
      'id': 'q',
      'kind': 'question',
      'answers': ['Mam'],
      'sentAt': 10,
    };
    FamilyQuestionReplyState state(List<Map<String, dynamic>> rows) =>
        familyQuestionReplyStates([question, ...rows], childUid: 'child')['q']!;

    test('raw operation projection overrides the coarse delivery flag', () {
      Map<String, dynamic> op(String? error) => {
        'id': 'op',
        'kind': 'answer',
        'replyTo': 'q',
        'senderUid': 'child',
        'delivery': 'failed',
        'operationError': error,
        'operationSigned': true,
      };
      expect(
        state([op('cancelled')]).status,
        FamilyQuestionReplyStatus.unknown,
      );
      expect(state([op('cancelled')]).blocksNewAnswer, true);
      expect(
        state([op('not-found')]).status,
        FamilyQuestionReplyStatus.unknown,
      );
      expect(state([op('not-found')]).blocksNewAnswer, true);
      final unsent = {...op('expired'), 'operationSigned': false};
      expect(state([unsent]).status, FamilyQuestionReplyStatus.failed);
      expect(state([unsent]).blocksNewAnswer, false);
    });

    Map<String, dynamic> marker({
      String sender = 'child',
      Object? kind,
      bool legacy = false,
      String? replyTo,
      int sentAt = 100,
    }) => {
      'id': 'marker',
      'kind': 'text',
      'text': 'redacted',
      'senderUid': sender,
      'sentAt': sentAt,
      'redactedOutcome': true,
      'delivery': 'failed',
      'sendOutcomeUnknown': true,
      if (!legacy) 'outcomeKind': kind,
      'replyTo': ?replyTo,
    };

    test('an associated answer marker blocks only its question', () {
      final rows = [
        question,
        {...question, 'id': 'other'},
        marker(kind: 'answer', replyTo: 'q'),
      ];
      final states = familyQuestionReplyStates(rows, childUid: 'child');
      expect(states['q']!.status, FamilyQuestionReplyStatus.unknown);
      expect(states['other']!.status, FamilyQuestionReplyStatus.unanswered);
      expect(
        state([marker(kind: 'text')]).status,
        FamilyQuestionReplyStatus.unanswered,
      );
    });

    test('legacy markers block earlier questions in the same input only', () {
      expect(
        state([marker(legacy: true)]).status,
        FamilyQuestionReplyStatus.unknown,
      );
      expect(
        state([marker(legacy: true, sentAt: 5)]).status,
        FamilyQuestionReplyStatus.unanswered,
      );
      expect(
        state([marker(legacy: true, sender: 'caregiver')]).status,
        FamilyQuestionReplyStatus.unanswered,
      );
      expect(
        familyQuestionReplyStates([
          question,
          marker(legacy: true),
        ], childUid: '')['q']!.status,
        FamilyQuestionReplyStatus.unanswered,
      );
    });

    test('a confirmed child answer still wins over any marker', () {
      final result = state([
        marker(legacy: true),
        {'id': 'a', 'kind': 'answer', 'replyTo': 'q', 'senderUid': 'child'},
      ]);
      expect(result.status, FamilyQuestionReplyStatus.confirmed);
      expect(result.replyId, 'a');
    });
  });
}

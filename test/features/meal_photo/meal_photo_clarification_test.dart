import 'dart:convert';

import 'package:diabeatthis/features/meal_photo/data/meal_photo_prompt.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_candidate.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_clarification_required.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/ports/meal_photo_candidate_repository.dart';
import 'package:diabeatthis/features/meal_photo/domain/ports/meal_photo_recognition_client.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;

Map<String, dynamic> clarificationPayload({
  String reason = 'ambiguous_menu_item',
}) => {
  'schema_version': 1,
  'status': 'needs_clarification',
  'reason': reason,
  'questions': ['Którą sekcję menu i pozycję masz na myśli?'],
};

class ClarifyingPhotoClient implements MealPhotoRecognitionClient {
  ClarifyingPhotoClient({required this.first, required this.second});
  final String first;
  final String second;
  int describes = 0;
  int resolves = 0;
  Map<String, List<MealPhotoCandidate>>? supplied;
  @override
  Future<String> describe(MealPhotoInput input) async {
    describes++;
    return first;
  }

  @override
  Future<String> resolve(
    MealPhotoInput input,
    String descriptionResponse,
    Map<String, List<MealPhotoCandidate>> candidates,
  ) async {
    resolves++;
    supplied = candidates;
    return second;
  }
}

class ClarificationCandidateReads implements MealPhotoCandidateRepository {
  final queries = <String>[];
  @override
  Future<List<MealPhotoCandidate>> search(
    String query, {
    required String languageCode,
    int limit = 8,
  }) async {
    queries.add(query);
    return [fixtures.candidate];
  }
}

void main() {
  test(
    'first-stage missing menu question stops catalog lookup and resolution before any proposal',
    () async {
      final raw = jsonEncode(clarificationPayload(reason: 'missing_menu'));
      final client = ClarifyingPhotoClient(
        first: raw,
        second: fixtures.proposal(),
      );
      final catalog = ClarificationCandidateReads();
      final useCase = ProposeMealFromPhotoUseCase(
        client: client,
        candidates: catalog,
      );
      await expectLater(
        useCase(
          const MealPhotoInput(
            mealPhotoPath: 'plate.jpg',
            description: 'Pozycja 4 z menu',
          ),
          languageCode: 'pl',
        ),
        throwsA(
          isA<MealPhotoClarificationRequired>()
              .having(
                (error) => error.reason,
                'reason',
                MealPhotoClarificationReason.missingMenu,
              )
              .having((error) => error.questions, 'questions', [
                'Którą sekcję menu i pozycję masz na myśli?',
              ])
              .having((error) => error.rawResponse, 'rawResponse', raw),
        ),
      );
      expect(client.describes, 1);
      expect(client.resolves, 0);
      expect(catalog.queries, isEmpty);
    },
  );
  test(
    'a valid first proposal needs no resolution or catalog lookup',
    () async {
      final client = ClarifyingPhotoClient(
        first: fixtures.proposal(),
        second: jsonEncode(clarificationPayload()),
      );
      final catalog = ClarificationCandidateReads();
      final returned =
          await ProposeMealFromPhotoUseCase(
            client: client,
            candidates: catalog,
          )(
            const MealPhotoInput(
              mealPhotoPath: 'plate.jpg',
              description: 'Potatoes',
            ),
            languageCode: 'pl',
          );
      expect(returned.itemized, hasLength(1));
      expect(catalog.queries, isEmpty);
      expect(client.resolves, 0);
      expect(client.supplied, isNull);
    },
  );
  test(
    'all supported clarification reasons preserve bounded questions and raw response',
    () {
      const parser = MealPhotoProposalParser();
      for (final entry in {
        'ambiguous_menu_item': MealPhotoClarificationReason.ambiguousMenuItem,
        'unreadable_menu': MealPhotoClarificationReason.unreadableMenu,
        'missing_menu': MealPhotoClarificationReason.missingMenu,
        'conflicting_evidence':
            MealPhotoClarificationReason.conflictingEvidence,
      }.entries) {
        final raw = jsonEncode(clarificationPayload(reason: entry.key));
        expect(
          () => parser.parse(raw),
          throwsA(
            isA<MealPhotoClarificationRequired>()
                .having((error) => error.reason, 'reason', entry.value)
                .having((error) => error.rawResponse, 'raw', raw),
          ),
        );
      }
    },
  );
  test(
    'clarification rejects proposal or nutrition fields and malformed questions',
    () {
      const parser = MealPhotoProposalParser();
      final invalid = <Map<String, dynamic>>[
        for (final key in [
          'itemized',
          'reference',
          'nutrition',
          'carbs',
          'name',
          'estimated_weight_grams',
        ])
          {...clarificationPayload(), key: null},
        {...clarificationPayload(), 'reason': 'guess'},
        {...clarificationPayload(), 'questions': []},
        {
          ...clarificationPayload(),
          'questions': ['a', 'b', 'c', 'd'],
        },
        {
          ...clarificationPayload(),
          'questions': [' '],
        },
        {
          ...clarificationPayload(),
          'questions': ['x' * 501],
        },
        {
          ...clarificationPayload(),
          'questions': [1],
        },
      ];
      for (final value in invalid) {
        expect(
          () => parser.parse(jsonEncode(value)),
          throwsFormatException,
          reason: jsonEncode(value),
        );
      }
      final proposal = jsonDecode(fixtures.proposal()) as Map<String, dynamic>;
      expect(
        () => parser.parse(jsonEncode({...proposal, 'status': 'partial'})),
        throwsFormatException,
      );
      expect(
        () => parser.parse(
          jsonEncode({
            ...proposal,
            'status': 'proposal',
            'questions': ['Which dish?'],
          }),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'explicit proposal status and legacy status absence preserve the proposal contract',
    () {
      const parser = MealPhotoProposalParser();
      final legacy = parser.parse(fixtures.proposal());
      final value = jsonDecode(fixtures.proposal()) as Map<String, dynamic>;
      value['status'] = 'proposal';
      final explicit = parser.parse(jsonEncode(value));
      expect(explicit.name, legacy.name);
      expect(explicit.reference.referenceNutrition!.carbs, 30);
    },
  );
  test(
    'menu selection instructions and actual attachment status reach both recognition stages',
    () {
      const prompt = MealPhotoPrompt();
      final missing = prompt.build(
        const MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          description: 'Pozycja 4 z menu',
        ),
      );
      final attached = prompt.build(
        const MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          menuPhotoPath: 'menu.jpg',
          description: 'Pozycja 4',
        ),
        descriptionResponse: 'previous',
      );
      expect(missing, contains('"menu_photo_attached":false'));
      expect(attached, contains('"menu_photo_attached":true'));
      for (final text in [missing, attached]) {
        expect(text, contains('ONLY that indicated item'));
        expect(text, contains('position numbers repeat'));
        expect(
          text,
          contains('without the user identifying a dish or position'),
        );
        expect(text, contains('BOTH description and resolution'));
        expect(text, contains('"status":"needs_clarification"'));
      }
    },
  );
}

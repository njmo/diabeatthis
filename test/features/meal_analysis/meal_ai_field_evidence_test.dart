import 'dart:convert';

import 'package:diabeatthis/common/analysis/dml_evidence_references.dart';
import 'package:diabeatthis/common/analysis/parse_analysis_sections.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' hide AcceptedMealAi;
import 'package:diabeatthis/features/meal_analysis/data/repositories/meal_ai_repository.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_draft.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_result.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/analyze_meal_ai_use_case.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_ai_test_fixtures.dart';
import 'meal_ai_workflow_test.dart' show FakeMealAiClient;

String responseWith({required List<String> refs, int length = 810}) {
  final response = jsonDecode(aiResponse()) as Map<String, dynamic>;
  final finding = response['sections']['response']['findings'][0];
  finding['evidence_refs'] = refs;
  finding['text'] = List.filled(length, 'a').join();
  return jsonEncode(response);
}

void main() {
  test(
    'complete response with a longer comparison and twelve actual field references is accepted end to end',
    () async {
      final document = await aiDocument();
      final paths = dmlEvidenceReferences(
        document.text,
        document.evidenceIds,
      ).where((ref) => ref.startsWith('meal_outcome.')).take(12).toList();
      expect(paths, hasLength(12));
      final raw = responseWith(refs: paths);
      final client = FakeMealAiClient()..output = raw;
      final draft = await AnalyzeMealAiUseCase(
        client: client,
        now: () => aiMealTime,
        promptVersion: 1,
      )(document, language: 'pl');
      final finding = draft.result.sections['response']!.findings.single;
      expect(finding.text.length, 810);
      expect(finding.evidenceRefs, paths);
      expect(draft.rawResponse, raw);
      expect(client.calls, 1);
    },
  );

  test('known section prefixes do not make invented fields valid', () async {
    final document = await aiDocument();
    for (final ref in [
      'meal_outcome.invented',
      'meal_cgm.blocks.0',
      'unknown.mean_mg_dl',
      'meal_before.iob_u.invented',
    ]) {
      expect(
        () => MealAiResult.parse(
          responseWith(refs: [ref]),
          language: 'pl',
          evidenceIds: document.evidenceIds,
          evidenceText: document.text,
        ),
        throwsFormatException,
        reason: ref,
      );
    }
  });

  test('missing fields cannot be verified without the original document', () {
    expect(
      () => MealAiResult.parse(
        responseWith(refs: ['meal_before.iob_u']),
        language: 'pl',
        evidenceIds: {'meal_before'},
      ),
      throwsFormatException,
    );
  });

  test(
    'object fields are enumerated exactly, arrays are not expanded into guessed paths',
    () {
      final refs = dmlEvidenceReferences(
        'DML/1\nmeal {"nested":{"value":1},"rows":[{"value":2}]}\nunknown {"value":3}',
        {'meal'},
      );
      expect(refs, {'meal', 'meal.nested', 'meal.nested.value', 'meal.rows'});
    },
  );

  test(
    'meal response remains bounded and shared day defaults are unchanged',
    () async {
      final document = await aiDocument();
      final refs = dmlEvidenceReferences(
        document.text,
        document.evidenceIds,
      ).where((ref) => ref.contains('.')).take(16).toList();
      final valid = responseWith(refs: refs, length: 1200);
      expect(
        () => MealAiResult.parse(
          valid,
          language: 'pl',
          evidenceIds: document.evidenceIds,
          evidenceText: document.text,
        ),
        returnsNormally,
      );
      for (final invalid in [
        responseWith(refs: [...refs, 'meal'], length: 810),
        responseWith(refs: ['meal'], length: 1201),
      ]) {
        expect(
          () => MealAiResult.parse(
            invalid,
            language: 'pl',
            evidenceIds: document.evidenceIds,
            evidenceText: document.text,
          ),
          throwsFormatException,
        );
      }
      for (final stricterDefault in [
        responseWith(refs: ['meal'], length: 810),
        responseWith(refs: List.filled(9, 'meal'), length: 50),
      ]) {
        expect(
          () => parseAnalysisSections(
            stricterDefault,
            language: 'pl',
            evidenceIds: document.evidenceIds,
            sectionNames: MealAiResult.sectionNames,
          ),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'accepted dotted evidence and longer text survive database reload',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO meal(id,name,planned_at,status) VALUES(1,'Synthetic meal',0,'eaten')",
      );
      final document = await aiDocument();
      final raw = responseWith(refs: ['meal_outcome.mean_mg_dl']);
      final accepted = AcceptedMealAi(
        acceptedAt: aiMealTime,
        draft: MealAiDraft(
          document: document,
          result: MealAiResult.parse(
            raw,
            language: 'pl',
            evidenceIds: document.evidenceIds,
            evidenceText: document.text,
          ),
          prompt: 'Synthetic prompt',
          rawResponse: raw,
          modelId: 'test',
          generatedAt: aiMealTime,
          promptVersion: 1,
        ),
      );
      final repo = MealAiRepository(db);
      await repo.save(accepted);
      final restored = (await repo.get(1))!;
      expect(restored.draft.result.encode(), accepted.draft.result.encode());
      expect(restored.draft.rawResponse, raw);
    },
  );
}

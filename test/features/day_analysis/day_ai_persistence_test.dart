import 'dart:convert';
import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_ai_repository.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_summary_repository.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/accepted_day_analysis.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_draft.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_result.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/accept_day_analysis_use_case.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_dml_use_case.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'day_analysis_api_test.dart' show analysisResponse;
import 'day_dml_test.dart' show dmlFixture;

DayAnalysisDraft savedDraft({String model = 'test-model'}) {
  final document = const BuildDayDmlUseCase()(dmlFixture());
  final raw = jsonEncode(analysisResponse());
  return DayAnalysisDraft(
    document: document,
    prompt: 'Exact historical instructions\n${document.text}',
    result: DayAnalysisResult.parse(
      raw,
      language: 'pl',
      evidenceIds: document.evidenceIds,
    ),
    modelId: model,
    rawResponse: raw,
    generatedAt: DateTime(2026, 10, 26, 9),
    promptVersion: 1,
  );
}

void main() {
  test(
    'v28 upgrade retains archive and accepted AI survives reopen and replacement',
    () async {
      final dir = await Directory.systemTemp.createTemp('day-ai-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/db.sqlite');
      var db = DatabaseImpl(NativeDatabase(file));
      final archive = dmlFixture();
      await DaySummaryRepository(db).insert(archive);
      await db.customStatement('DROP TABLE accepted_day_ai');
      await db.customStatement('PRAGMA user_version = 28');
      await db.close();
      db = DatabaseImpl(NativeDatabase(file));
      final repo = DayAiRepository(db);
      expect(await repo.get(archive.snapshot.dayKey), isNull);
      final draft = savedDraft();
      final at = DateTime(2026, 10, 26, 10);
      await AcceptDayAnalysisUseCase(save: repo.save, now: () => at)(
        archive.snapshot.dayKey,
        draft,
      );
      await db.close();
      db = DatabaseImpl(NativeDatabase(file));
      addTearDown(db.close);
      final reopened = DayAiRepository(db);
      final saved = (await reopened.get(archive.snapshot.dayKey))!;
      expect(saved.acceptedAt, at);
      expect(saved.analysis.document.text, draft.document.text);
      expect(saved.analysis.document.evidenceIds, draft.document.evidenceIds);
      expect(saved.analysis.rawResponse, draft.rawResponse);
      expect(saved.analysis.result.encode(), draft.result.encode());
      expect(saved.analysis.modelId, draft.modelId);
      expect(saved.analysis.promptVersion, 1);
      expect(saved.analysis.prompt, draft.prompt);
      expect(saved.analysis.generatedAt, draft.generatedAt);
      await reopened.save(
        archive.snapshot.dayKey,
        AcceptedDayAnalysis(
          analysis: savedDraft(model: 'replacement'),
          acceptedAt: at,
        ),
      );
      expect(
        (await reopened.get(archive.snapshot.dayKey))!.analysis.modelId,
        'replacement',
      );
      expect(
        (await DaySummaryRepository(
          db,
        ).get(archive.snapshot.dayKey))!.snapshot.encode(),
        archive.snapshot.encode(),
      );
    },
  );

  test('legacy archive without prompt preserves DML and result', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final archive = dmlFixture();
    await DaySummaryRepository(db).insert(archive);
    final repo = DayAiRepository(db);
    final draft = savedDraft();
    await repo.save(
      archive.snapshot.dayKey,
      AcceptedDayAnalysis(analysis: draft, acceptedAt: DateTime(2026, 10, 26)),
    );
    final row = await db.select(db.acceptedDayAi).getSingle();
    final payload = jsonDecode(row.payload) as Map<String, dynamic>;
    payload.remove('prompt');
    await db.customStatement('UPDATE accepted_day_ai SET payload = ?', [
      jsonEncode(payload),
    ]);
    final restored = (await repo.get(archive.snapshot.dayKey))!.analysis;
    expect(restored.prompt, isNull);
    expect(restored.document.text, draft.document.text);
    expect(restored.result.encode(), draft.result.encode());
  });

  test('AI cannot be saved for an unaccepted day', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    await expectLater(
      DayAiRepository(db).save(
        '2026-10-25',
        AcceptedDayAnalysis(
          analysis: savedDraft(),
          acceptedAt: DateTime(2026, 10, 26),
        ),
      ),
      throwsA(anything),
    );
  });
}

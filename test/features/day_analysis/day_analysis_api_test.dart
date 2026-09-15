import 'dart:convert';

import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/core/llm/providers/firebase_ai_llm_client_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/clients/llm_day_analysis_client.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_analysis_history_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_analysis_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_summary_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_meal_batch.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_result.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/analyze_day_summary_use_case.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_dml_use_case.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/load_day_analysis_history_use_case.dart';
import 'package:diabeatthis/features/day_analysis/presentation/controllers/day_analysis_input_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'day_dml_test.dart' show dmlFixture;

Map<String, dynamic> analysisResponse() => {
  'schema_version': 1,
  'language': 'pl',
  'sections': {
    for (final name in DayAnalysisResult.sectionNames)
      name: {
        'status': 'insufficient_data',
        'summary': '',
        'findings': [],
        'missing_data': ['cgm_series'],
      },
  },
};

class RecordingDayTransport implements LocalLlmClient {
  LocalLlmRequest? request;
  String response = jsonEncode(analysisResponse());
  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async {
    this.request = request;
    return LocalLlmResponse(text: response);
  }
}

void main() {
  test(
    'same use case works with any injected transport and returns an unsaved validated draft',
    () async {
      final transport = RecordingDayTransport();
      final now = DateTime.utc(2026, 10, 26, 9);
      final accepted = dmlFixture();
      final payload = accepted.snapshot.encode();
      final useCase = AnalyzeDaySummaryUseCase(
        client: LlmDayAnalysisClient(
          transport: transport,
          modelId: 'test-local',
        ),
        now: () => now,
        promptVersion: 1,
      );
      final draft = await useCase(
        const BuildDayDmlUseCase()(accepted),
        language: 'pl',
      );
      expect(draft.modelId, 'test-local');
      expect(draft.generatedAt, now);
      expect(draft.result.sections.keys, DayAnalysisResult.sectionNames);
      expect(transport.request!.imagePaths, isEmpty);
      expect(transport.request!.prompt, contains(draft.document.text));
      expect(
        transport.request!.prompt,
        contains('bolus_total_units INCLUDES smb_units'),
      );
      expect(accepted.snapshot.encode(), payload);
      transport.request = null;
      await expectLater(
        useCase(
          const BuildDayDmlUseCase()(accepted),
          language: 'invalid\ninstruction',
        ),
        throwsArgumentError,
      );
      expect(transport.request, isNull);
    },
  );

  test('invalid model output never becomes a review draft', () async {
    final transport = RecordingDayTransport()..response = '{"schema_version":';
    final useCase = AnalyzeDaySummaryUseCase(
      client: LlmDayAnalysisClient(transport: transport, modelId: 'fake'),
      now: DateTime.now,
      promptVersion: 1,
    );
    await expectLater(
      useCase(const BuildDayDmlUseCase()(dmlFixture()), language: 'pl'),
      throwsFormatException,
    );
  });

  test(
    'JSON validation rejects missing sections, wrong languages, invalid enums and invented evidence',
    () {
      final variants = <Map<String, dynamic>>[];
      variants.add(analysisResponse()..['language'] = 'en');
      variants.add(analysisResponse()..['schema_version'] = 2);
      final missing = analysisResponse();
      (missing['sections'] as Map).remove('night');
      variants.add(missing);
      final extra = analysisResponse()..['unexpected'] = true;
      variants.add(extra);
      for (final change in [
        {'kind': 'diagnosis'},
        {'confidence': 'certain'},
        {
          'evidence_refs': ['invented:42'],
        },
        {'evidence_refs': []},
      ]) {
        final variant = analysisResponse();
        variant['sections']['glucose']['findings'] = [
          {
            'title': 'Test',
            'text': 'Test',
            'kind': 'observation',
            'confidence': 'low',
            'evidence_refs': ['glucose'],
            ...change,
          },
        ];
        variants.add(variant);
      }
      for (final variant in variants) {
        expect(
          () => DayAnalysisResult.parse(
            jsonEncode(variant),
            language: 'pl',
            evidenceIds: {'glucose'},
          ),
          throwsFormatException,
        );
      }
      final valid = analysisResponse();
      valid['sections']['glucose']['findings'] = [
        {
          'title': 'Test',
          'text': 'Test',
          'kind': 'observation',
          'confidence': 'low',
          'evidence_refs': ['glucose'],
        },
      ];
      final parsed = DayAnalysisResult.parse(
        jsonEncode(valid),
        language: 'pl',
        evidenceIds: {'glucose'},
      );
      expect(jsonDecode(parsed.encode()), valid);
      expect(() => parsed.sections.clear(), throwsUnsupportedError);
      expect(
        () => parsed.sections['glucose']!.findings.first.evidenceRefs.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'DML provider combines archive and history without creating an AI client or modifying the archive',
    () async {
      final date = DateTime(2026, 10, 25);
      final accepted = dmlFixture();
      final original = accepted.snapshot.encode();
      final container = ProviderContainer(
        overrides: [
          loadDayAnalysisHistoryProvider.overrideWith(
            (ref) => LoadDayAnalysisHistoryUseCase(
              now: () => DateTime.utc(2026, 10, 26, 8),
              loadGlucose: (s, e) async => [],
              loadStatuses: (s, e) async => [],
              loadTreatments: (s, e) async => [],
              loadMeals: (s, e) async => DayAnalysisMealBatch(meals: []),
              loadLows: (s, e) async => [],
              loadActivities: (s, e) async => [],
            ),
          ),
          dayAnalysisClientProvider.overrideWith(
            (ref) => throw StateError('No AI initialization'),
          ),
          acceptedDaySummaryProvider(
            date,
          ).overrideWith((ref) async => accepted),
          daySummaryDraftProvider(
            date,
          ).overrideWith((ref) => throw StateError('No live history')),
          firebaseAiLlmClientProvider.overrideWith(
            (ref) => throw StateError('No remote initialization'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final document = await container.read(dayDmlProvider(date).future);
      expect(document!.text, contains('DML/1'));
      expect(document.text, contains('CGM '));
      expect(accepted.snapshot.encode(), original);
    },
  );
}

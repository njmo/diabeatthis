import 'package:diabeatthis/features/day_analysis/data/providers/accepted_day_ai_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_analysis_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_summary_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/accepted_day_analysis.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_response.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_dml_document.dart';
import 'package:diabeatthis/features/day_analysis/domain/services/day_analysis_client.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/accept_day_analysis_use_case.dart';
import 'package:diabeatthis/features/day_analysis/presentation/controllers/day_ai_controller.dart';
import 'package:diabeatthis/features/day_analysis/presentation/controllers/day_analysis_input_controller.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_ai_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'day_ai_persistence_test.dart' show savedDraft;
import 'day_ai_saved_preview_test.dart' show PreviewDayAi;
import 'day_dml_test.dart' show dmlFixture;

class ProbeInput extends DayAnalysisInputController {
  final VoidCallback onBuild;
  ProbeInput(super.date, this.onBuild);
  @override
  Future<DayDmlDocument?> build() async {
    onBuild();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return savedDraft().document;
  }
}

class ProbeClient implements DayAnalysisClient {
  @override
  String get modelId => 'test';
  @override
  Future<DayAnalysisResponse> analyze(
    DayDmlDocument document, {
    required String language,
  }) async => DayAnalysisResponse(
    prompt: savedDraft().prompt!,
    text: savedDraft().rawResponse,
  );
}

void main() {
  final date = DateTime(2026, 10, 25);
  testWidgets('regeneration reuses prepared history', (tester) async {
    var loads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          acceptedDayAiProvider(date).overrideWith(
            (ref) async =>
                AcceptedDayAnalysis(analysis: savedDraft(), acceptedAt: date),
          ),
          acceptedDaySummaryProvider(
            date,
          ).overrideWith((ref) async => dmlFixture()),
          dayDmlProvider(
            date,
          ).overrideWith(() => ProbeInput(date, () => loads++)),
          dayAnalysisClientProvider.overrideWithValue(ProbeClient()),
        ],
        child: localizedMaterialApp(
          home: Scaffold(body: DayAiButton(date: date)),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Analiza AI'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Wygeneruj ponownie'));
      await tester.pumpAndSettle();
    }
    expect(loads, 1);
  });

  testWidgets('discard clears obsolete save error', (tester) async {
    final request = (date: date, language: 'pl');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          acceptedDayAiProvider(date).overrideWith(
            (ref) async =>
                AcceptedDayAnalysis(analysis: savedDraft(), acceptedAt: date),
          ),
          acceptedDaySummaryProvider(
            date,
          ).overrideWith((ref) async => dmlFixture()),
          dayAiControllerProvider(
            request,
          ).overrideWith(() => PreviewDayAi(request)),
          acceptDayAnalysisUseCaseProvider.overrideWithValue(
            AcceptDayAnalysisUseCase(
              now: () => date,
              save: (_, _) async => throw StateError('disk'),
            ),
          ),
        ],
        child: localizedMaterialApp(
          home: Scaffold(body: DayAiButton(date: date)),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Analiza AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zaakceptuj i zastąp zapisaną analizę'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odrzuć propozycję'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Nie udało się zapisać analizy. Propozycja pozostaje dostępna.',
      ),
      findsNothing,
    );
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/features/day_analysis/data/prompts/day_analysis_prompt.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/accepted_day_ai_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_analysis_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_summary_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_response.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_dml_document.dart';
import 'package:diabeatthis/features/day_analysis/domain/services/day_analysis_client.dart';
import 'package:diabeatthis/features/day_analysis/presentation/controllers/day_analysis_input_controller.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_ai_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'day_analysis_api_test.dart' show analysisResponse;
import 'day_dml_test.dart' show FixtureDayAnalysisInputController, dmlFixture;

class ButtonTestAnalysisClient implements DayAnalysisClient {
  @override
  String get modelId => 'test';
  int calls = 0;
  final pending = Completer<String>();
  @override
  Future<DayAnalysisResponse> analyze(
    DayDmlDocument document, {
    required String language,
  }) {
    calls++;
    return pending.future.then(
      (text) => DayAnalysisResponse(
        prompt: buildDayAnalysisPrompt(document, language),
        text: text,
      ),
    );
  }
}

void main() {
  final date = DateTime(2026, 10, 25);
  testWidgets(
    'sparkle opens preview, generation is explicit and repeated taps do not duplicate requests',
    (tester) async {
      final client = ButtonTestAnalysisClient();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            acceptedDayAiProvider.overrideWith((ref, date) async => null),
            dayDmlProvider(
              date,
            ).overrideWith(() => FixtureDayAnalysisInputController(date)),
            acceptedDaySummaryProvider(
              date,
            ).overrideWith((ref) async => dmlFixture()),
            dayAnalysisClientProvider.overrideWithValue(client),
          ],
          child: localizedMaterialApp(
            home: Scaffold(body: DayAiButton(date: date)),
          ),
        ),
      );
      expect(client.calls, 0);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      await tester.tap(find.byTooltip('Analiza AI'));
      await tester.pumpAndSettle();
      expect(client.calls, 0);
      await tester.tap(find.text('Analizuj dzień'));
      await tester.pump();
      expect(client.calls, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text('Analizuję podsumowanie dnia…'), findsOneWidget);
      final response = analysisResponse();
      response['sections']['overview']['summary'] = 'Podsumowanie testowe';
      client.pending.complete(jsonEncode(response));
      await tester.pumpAndSettle();
      expect(find.text('Podsumowanie testowe'), findsOneWidget);
      expect(find.text('Podgląd analizy — nie jest zapisany.'), findsOneWidget);
      expect(find.text('Wygeneruj ponownie'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unaccepted day cannot start model generation', (tester) async {
    final client = ButtonTestAnalysisClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          acceptedDayAiProvider.overrideWith((ref, date) async => null),
          dayDmlProvider(
            date,
          ).overrideWith(() => FixtureDayAnalysisInputController(date)),
          acceptedDaySummaryProvider(date).overrideWith((ref) async => null),
          dayAnalysisClientProvider.overrideWithValue(client),
        ],
        child: localizedMaterialApp(
          home: Scaffold(body: DayAiButton(date: date)),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Analiza AI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('po zatwierdzeniu'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(client.calls, 0);
  });

  testWidgets('closing during generation safely ignores a late response', (
    tester,
  ) async {
    final client = ButtonTestAnalysisClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          acceptedDayAiProvider.overrideWith((ref, date) async => null),
          dayDmlProvider(
            date,
          ).overrideWith(() => FixtureDayAnalysisInputController(date)),
          acceptedDaySummaryProvider(
            date,
          ).overrideWith((ref) async => dmlFixture()),
          dayAnalysisClientProvider.overrideWithValue(client),
        ],
        child: localizedMaterialApp(
          home: Scaffold(body: DayAiButton(date: date)),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Analiza AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analizuj dzień'));
    await tester.pump();
    await tester.tap(find.byTooltip('Zamknij analizę'));
    await tester.pumpAndSettle();
    client.pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Analiza AI'), findsOneWidget);
  });
}

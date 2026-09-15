import 'dart:async';

import 'package:diabeatthis/features/day_analysis/data/providers/accepted_day_ai_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_analysis_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_summary_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/accepted_day_analysis.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/accept_day_analysis_use_case.dart';
import 'package:diabeatthis/features/day_analysis/presentation/controllers/day_ai_controller.dart';
import 'package:diabeatthis/features/day_analysis/presentation/controllers/day_ai_state.dart';
import 'package:diabeatthis/features/day_analysis/presentation/controllers/day_analysis_input_controller.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_ai_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'day_ai_persistence_test.dart' show savedDraft;
import 'day_dml_test.dart' show dmlFixture;

void main() {
  final date = DateTime(2026, 10, 25);
  testWidgets(
    'reopening saved analysis and input never loads history or model',
    (tester) async {
      final stored = AcceptedDayAnalysis(
        analysis: savedDraft(),
        acceptedAt: date,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            acceptedDayAiProvider(date).overrideWith((ref) async => stored),
            acceptedDaySummaryProvider(
              date,
            ).overrideWith((ref) async => dmlFixture()),
            dayAnalysisClientProvider.overrideWith(
              (ref) => throw StateError('Must not initialize model'),
            ),
            dayDmlProvider(date).overrideWith(() => ForbiddenDayInput(date)),
          ],
          child: localizedMaterialApp(
            home: Scaffold(body: DayAiButton(date: date)),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Analiza AI'));
      await tester.pumpAndSettle();
      expect(find.text('Zapisana analiza'), findsOneWidget);
      expect(find.text('Zaakceptuj i zapisz'), findsNothing);
      await tester.tap(find.byIcon(Icons.subject));
      await tester.pumpAndSettle();
      expect(find.text(stored.analysis.prompt!), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'discarding replacement preserves saved analysis without writing',
    (tester) async {
      var saves = 0;
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
                save: (_, _) async {
                  saves++;
                },
              ),
            ),
            dayDmlProvider(date).overrideWith(() => ForbiddenDayInput(date)),
          ],
          child: localizedMaterialApp(
            home: Scaffold(body: DayAiButton(date: date)),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Analiza AI'));
      await tester.pumpAndSettle();
      expect(find.text('Zaakceptuj i zastąp zapisaną analizę'), findsOneWidget);
      await tester.tap(find.text('Odrzuć propozycję'));
      await tester.pumpAndSettle();
      expect(find.text('Zapisana analiza'), findsOneWidget);
      expect(find.text('Odrzuć propozycję'), findsNothing);
      expect(saves, 0);
      expect(tester.takeException(), isNull);
    },
  );

  test('duplicate acceptance is blocked while saving', () async {
    final pending = Completer<void>();
    var saves = 0;
    final container = ProviderContainer(
      overrides: [
        dayAiControllerProvider((
          date: date,
          language: 'pl',
        )).overrideWith(() => PreviewDayAi((date: date, language: 'pl'))),
        acceptDayAnalysisUseCaseProvider.overrideWithValue(
          AcceptDayAnalysisUseCase(
            now: () => date,
            save: (key, value) {
              saves++;
              return pending.future;
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      dayAiControllerProvider((date: date, language: 'pl')),
      (_, _) {},
    );
    addTearDown(subscription.close);
    container.read(dayAiControllerProvider((date: date, language: 'pl')));
    final controller = container.read(
      dayAiControllerProvider((date: date, language: 'pl')).notifier,
    );
    final first = controller.accept();
    await controller.accept();
    expect(saves, 1);
    pending.complete();
    await first;
    expect(
      container
          .read(dayAiControllerProvider((date: date, language: 'pl')))
          .draft,
      isNull,
    );
  });

  test(
    'failed acceptance can be retried and only successful save replaces archive',
    () async {
      var attempts = 0;
      AcceptedDayAnalysis? stored;
      final container = ProviderContainer(
        overrides: [
          dayAiControllerProvider((
            date: date,
            language: 'pl',
          )).overrideWith(() => PreviewDayAi((date: date, language: 'pl'))),
          acceptDayAnalysisUseCaseProvider.overrideWithValue(
            AcceptDayAnalysisUseCase(
              now: () => date,
              save: (key, value) async {
                expect(key, '2026-10-25');
                attempts++;
                if (attempts == 1) throw StateError('disk failure');
                stored = value;
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        dayAiControllerProvider((date: date, language: 'pl')),
        (_, _) {},
      );
      addTearDown(subscription.close);
      container.read(dayAiControllerProvider((date: date, language: 'pl')));
      final controller = container.read(
        dayAiControllerProvider((date: date, language: 'pl')).notifier,
      );
      final draft = container
          .read(dayAiControllerProvider((date: date, language: 'pl')))
          .draft!;
      await controller.accept();
      expect(stored, isNull);
      expect(
        container
            .read(dayAiControllerProvider((date: date, language: 'pl')))
            .saveError,
        isNotNull,
      );
      await controller.accept();
      expect(stored!.analysis, same(draft));
      expect(stored!.acceptedAt, date);
    },
  );
}

class ForbiddenDayInput extends DayAnalysisInputController {
  ForbiddenDayInput(super.date);
  @override
  Future<Never> build() async => throw StateError('Must not load history');
}

class PreviewDayAi extends DayAiController {
  PreviewDayAi(super.request);
  @override
  DayAiState build() => DayAiState(draft: savedDraft(model: 'new-model'));
}

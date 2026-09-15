import 'package:diabeatthis/features/day_analysis/data/prompts/day_analysis_prompt.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_analysis_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_summary_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_dml_use_case.dart';
import 'package:diabeatthis/features/day_analysis/presentation/controllers/day_analysis_input_controller.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_ai_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'day_dml_test.dart' show FixtureDayAnalysisInputController, dmlFixture;

void main() {
  testWidgets(
    'input preview and copy contain the complete prompt without initializing AI',
    (tester) async {
      final date = DateTime(2026, 10, 25);
      final summary = dmlFixture();
      final expected = buildDayAnalysisPrompt(
        const BuildDayDmlUseCase()(summary),
        'pl',
      );
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dayDmlProvider(
              date,
            ).overrideWith(() => FixtureDayAnalysisInputController(date)),
            acceptedDaySummaryProvider(
              date,
            ).overrideWith((ref) async => summary),
            dayAnalysisClientProvider.overrideWith(
              (ref) => throw StateError('Preview must not initialize AI'),
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(body: DayAiSheet(date: date)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dane wejściowe AI'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        expected,
      );
      await tester.tap(find.byTooltip('Kopiuj cały tekst'));
      await tester.pumpAndSettle();
      expect(clipboard, expected);
      expect(find.text('Skopiowano dane wejściowe AI'), findsOneWidget);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.text('Analizuj dzień'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

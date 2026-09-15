import 'package:diabeatthis/features/day_analysis/data/providers/accepted_day_ai_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_analysis_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_summary_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_invalid_response.dart';
import 'package:diabeatthis/features/day_analysis/presentation/controllers/day_analysis_input_controller.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_ai_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'day_ai_button_test.dart' show ButtonTestAnalysisClient;
import 'day_dml_test.dart' show FixtureDayAnalysisInputController, dmlFixture;

void main() {
  test('invalid response is not included in exception text', () {
    const error = DayAnalysisInvalidResponse(
      response: 'private output',
      reason: 'Invalid JSON',
    );
    expect(error.toString(), isNot(contains('private output')));
    expect(error.response, 'private output');
  });

  testWidgets('rejected JSON can be inspected without another model request', (
    tester,
  ) async {
    final date = DateTime(2026, 10, 25);
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
          home: Scaffold(body: DayAiSheet(date: date)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analizuj dzień'));
    await tester.pump();
    const response = '{"sections": {"overview":';
    client.pending.complete(response);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Model zwrócił nieprawidłową lub niepełną odpowiedź. Spróbuj wygenerować analizę ponownie.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Odpowiedź AI · JSON'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      response,
    );
    expect(client.calls, 1);
    expect(tester.takeException(), isNull);
  });
}

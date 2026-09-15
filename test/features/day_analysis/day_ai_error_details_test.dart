import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_ai_error_details_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets('provider failure is available on demand as selectable text', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const Scaffold(
          body: DayAiErrorDetailsButton(
            error: LlmRequestException(
              failure: LlmRequestFailure.unavailable,
              message: 'models/test is not found',
            ),
          ),
        ),
      ),
    );
    expect(find.text('models/test is not found'), findsNothing);
    await tester.tap(find.text('Szczegóły błędu AI'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(SelectableText, 'models/test is not found'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

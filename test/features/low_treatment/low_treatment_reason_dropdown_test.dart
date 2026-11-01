import 'package:diabeatthis/core/domain/model/low_treatment_context.dart';
import 'package:diabeatthis/features/low_treatment/presentation/widgets/low_treatment_reason_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  for (final hasSuggestion in [false, true]) {
    testWidgets(
      'reason dropdown preserves automatic selection and allows changing it (suggestion=$hasSuggestion)',
      (tester) async {
        var reason = hasSuggestion
            ? LowTreatmentReason.carbsReq
            : LowTreatmentReason.lowGlucose;
        await tester.pumpWidget(
          localizedMaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: LowTreatmentReasonSelector(
                  value: reason,
                  hasAapsSuggestion: hasSuggestion,
                  onChanged: (value) => setState(() => reason = value),
                ),
              ),
            ),
          ),
        );
        expect(
          tester
              .widget<DropdownButtonFormField<LowTreatmentReason>>(
                find.byType(DropdownButtonFormField<LowTreatmentReason>),
              )
              .initialValue,
          reason,
        );
        await tester.tap(
          find.byType(DropdownButtonFormField<LowTreatmentReason>),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Szybki spadek').last);
        await tester.pumpAndSettle();
        expect(reason, LowTreatmentReason.fallingTrend);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('reason dropdown fits a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      localizedMaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: LowTreatmentReasonSelector(
              value: LowTreatmentReason.carbsReq,
              hasAapsSuggestion: true,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<LowTreatmentReason>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

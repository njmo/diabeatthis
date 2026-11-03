import 'package:diabeatthis/features/low_treatment/data/providers/low_treatment_upload_provider.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/recorded_low_treatment.dart';
import 'package:diabeatthis/features/low_treatment/presentation/widgets/recorded_low_treatment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'shows consumed ingredients inline without a navigation control',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lowTreatmentUploadStatusProvider(
              42,
            ).overrideWith((ref) => Stream.value(null)),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: RecordedLowTreatmentCard(
                treatment: RecordedLowTreatment(
                  mealId: 42,
                  eatenAt: DateTime(2026, 9, 5, 10, 21),
                  netCarbsGrams: 7.35,
                  ingredients: const [(name: 'Juice', grams: 75)],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Juice'), findsOneWidget);
      expect(find.text('75 g'), findsOneWidget);
      expect(find.text('7,35 g'), findsOneWidget);
      expect(find.text('5.09 10:21'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'dart:async';

import 'package:diabeatthis/core/domain/model/stress_level.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/low_treatment_observation_context_data.dart';
import 'package:diabeatthis/features/low_treatment/presentation/providers/low_treatment_observation_context_provider.dart';
import 'package:diabeatthis/features/low_treatment/presentation/widgets/low_treatment_observation_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'optional observations do not block controls while loading or failing',
    (tester) async {
      final pending = Completer<LowTreatmentObservationContextData>();
      var saves = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lowTreatmentObservationContextProvider.overrideWith(
              (ref) => pending.future,
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  const LowTreatmentObservationContext(),
                  TextButton(
                    onPressed: () => saves++,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Save'));
      expect(saves, 1);
      expect(find.byType(Chip), findsNothing);
      pending.completeError(StateError('Unavailable'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Save'));
      expect(saves, 2);
    },
  );

  testWidgets('shows recorded activity and stress with times', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lowTreatmentObservationContextProvider.overrideWith(
            (ref) async => LowTreatmentObservationContextData(
              activityName: 'Athletics',
              activityStartsAt: now.add(const Duration(minutes: 30)),
              stressLevel: StressLevel.high,
              stressObservedAt: now.subtract(const Duration(minutes: 20)),
            ),
          ),
        ],
        child: localizedMaterialApp(
          home: const Scaffold(body: LowTreatmentObservationContext()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Chip), findsNWidgets(2));
    expect(find.textContaining('Athletics'), findsOneWidget);
    expect(find.textContaining('Zapisany stres'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:diabeatthis/common/models/timeline_relation.dart';
import 'package:diabeatthis/common/widgets/timeline_relation_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'picker uses consumption day and returns a future activity only after selection',
    (tester) async {
      final at = DateTime(2026, 10, 28, 7, 50);
      final pe = TimelineRelation(
        id: 3,
        kind: TimelineRelationKind.activity,
        name: 'PE',
        at: DateTime(2026, 10, 28, 8),
      );
      DateTime? loadedDay;
      TimelineRelation? result;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<TimelineRelation>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => TimelineRelationPicker(
                      occurredAt: at,
                      load: (day) async {
                        loadedDay = day;
                        return [pe];
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(loadedDay, DateTime(2026, 10, 28));
      expect(result, isNull);
      expect(find.text('28.10.2026 08:00'), findsOneWidget);
      await tester.tap(find.text('PE'));
      await tester.pumpAndSettle();
      expect(result, same(pe));
    },
  );

  testWidgets('picker handles loading failure with retry', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: TimelineRelationPicker(
            occurredAt: DateTime(2026, 10, 28),
            load: (_) async {
              if (++attempts == 1) throw StateError('Unavailable');
              return [];
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nie udało się wczytać. Spróbuj ponownie'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(
      find.text('Brak aktywności i posiłków w tym dniu. Wybierz inny dzień.'),
      findsOneWidget,
    );
  });
}

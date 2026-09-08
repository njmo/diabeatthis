import 'package:diabeatthis/common/widgets/date_time_picker.dart';
import 'package:diabeatthis/core/data_sources/stress_events/stress_event_repository.dart';
import 'package:diabeatthis/core/domain/model/stress_level.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/manual_events/presentation/widgets/manual_event_sheet.dart';
import 'package:diabeatthis/features/manual_events/presentation/widgets/manual_event_time_field.dart';
import 'package:diabeatthis/features/manual_events/presentation/widgets/stress_end_time_field.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  late DatabaseImpl db;
  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: localizedMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showManualEventSheet(context),
                child: const Text('Otwórz'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Otwórz'));
    await tester.pumpAndSettle();
  }

  test('end time uses the start date and supports crossing midnight', () {
    expect(
      endTimeForStart(
        DateTime(2026, 1, 1, 12, 6),
        const TimeOfDay(hour: 13, minute: 6),
      ),
      DateTime(2026, 1, 1, 13, 6),
    );
    expect(
      endTimeForStart(
        DateTime(2026, 1, 31, 23),
        const TimeOfDay(hour: 1, minute: 0),
      ),
      DateTime(2026, 2, 1, 1),
    );
  });

  testWidgets('past 12:06 to 13:06 stress saves with a time-only end picker', (
    tester,
  ) async {
    await open(tester);
    tester
        .widget<ManualEventTimeField>(find.byType(ManualEventTimeField))
        .onChanged(DateTime(2026, 1, 1, 12, 6));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('Do: 13:06'), findsOneWidget);
    await tester.tap(find.byType(StressEndTimeField));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
    Navigator.of(tester.element(find.byType(TimePickerDialog))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zapisz zdarzenie'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => StressEventRepository(
        db,
      ).watchEvents().firstWhere((events) => events.isNotEmpty),
    );
    await tester.pumpAndSettle();
    final events = await StressEventRepository(
      db,
    ).between(DateTime(2026), DateTime(2027));
    expect(events.single.occurredAt, DateTime(2026, 1, 1, 12, 6));
    expect(events.single.endedAt, DateTime(2026, 1, 1, 13, 6));
  });

  testWidgets('a future end does not block saving stress', (tester) async {
    await open(tester);
    final now = DateTime.now();
    final start = now.subtract(const Duration(minutes: 10));
    final end = now.add(const Duration(hours: 1));
    tester
        .widget<ManualEventTimeField>(find.byType(ManualEventTimeField))
        .onChanged(start);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    tester
        .widget<StressEndTimeField>(find.byType(StressEndTimeField))
        .onChanged(end);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zapisz zdarzenie'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => StressEventRepository(
        db,
      ).watchEvents().firstWhere((events) => events.isNotEmpty),
    );
    await tester.pumpAndSettle();
    final events = await StressEventRepository(db).between(start, end);
    expect(
      events.single.endedAt!.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    );
    expect(find.byType(ManualEventSheet), findsNothing);
  });

  testWidgets('stress needs no numeric value and preserves the note', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Stres'), findsOneWidget);
    expect(find.text('Podana dawka'), findsNothing);
    expect(find.text('Glikemia'), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.tap(find.text('Wysoki'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Trudny dzień');
    await tester.tap(find.text('Zapisz zdarzenie'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => StressEventRepository(
        db,
      ).watchEvents().firstWhere((events) => events.isNotEmpty),
    );
    await tester.pumpAndSettle();
    final events = await StressEventRepository(
      db,
    ).between(DateTime(2000), DateTime(2100));
    expect(events.single.stressLevel, StressLevel.high);
    expect(events.single.notes, 'Trudny dzień');
  });
}

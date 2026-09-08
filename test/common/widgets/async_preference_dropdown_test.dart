import 'package:diabeatthis/common/widgets/async_preference_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets('failed save restores the saved value and allows retry', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncPreferenceDropdown<int>(
            value: const AsyncData(1),
            label: 'Motyw',
            loadError: 'Błąd odczytu',
            saveError: 'Błąd zapisu',
            items: const [
              DropdownMenuItem(value: 1, child: Text('Pierwszy')),
              DropdownMenuItem(value: 2, child: Text('Drugi')),
            ],
            onSave: (value) async {
              calls++;
              throw StateError('Persistence failed');
            },
          ),
        ),
      ),
    );
    for (var attempt = 1; attempt <= 2; attempt++) {
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drugi').last);
      await tester.pumpAndSettle();
      expect(calls, attempt);
      final field = tester.state<FormFieldState<int>>(
        find.byType(DropdownButtonFormField<int>),
      );
      expect(field.value, 1);
      expect(find.text('Błąd zapisu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

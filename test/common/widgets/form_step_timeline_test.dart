import 'package:diabeatthis/common/widgets/form_step_timeline.dart';
import 'package:diabeatthis/common/widgets/form_task_timeline_item.dart';
import 'package:diabeatthis/common/widgets/form_timeline_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'vertical progress keeps long translated labels on one line and emphasizes the active step',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                child: FormStepTimeline(
                  labels: const [
                    'Zdjęcie',
                    'Produkty',
                    'Gramatura',
                    'Podsumowanie',
                  ],
                  currentStep: 1,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      for (final title in [
        'Zdjęcie',
        'Produkty',
        'Gramatura',
        'Podsumowanie',
      ]) {
        final text = tester.widget<Text>(find.text(title));
        expect(text.maxLines, 1);
        expect(text.softWrap, isFalse);
      }
      final active = tester.widget<Text>(find.text('Produkty'));
      final pending = tester.widget<Text>(find.text('Podsumowanie'));
      expect(active.style!.fontSize!, greaterThan(pending.style!.fontSize!));
      final markers = tester
          .widgetList<FormTimelineMarker>(find.byType(FormTimelineMarker))
          .toList();
      expect(markers.map((marker) => marker.status), [
        FormTimelineStatus.completed,
        FormTimelineStatus.active,
        FormTimelineStatus.pending,
        FormTimelineStatus.pending,
      ]);
      expect(find.byIcon(Icons.check), findsOneWidget);
    },
  );
  testWidgets(
    'completed task is compact and can expand its existing input for editing',
    (tester) async {
      var expanded = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => FormTaskTimelineItem(
                title: 'Meal category',
                subtitle: 'Lunch',
                completed: true,
                active: expanded,
                onTap: () => setState(() => expanded = !expanded),
                child: const Text('Category editor'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Category editor'), findsNothing);
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.text('Meal category'));
      await tester.pump();
      expect(find.text('Category editor'), findsOneWidget);
      expect(find.text('Lunch'), findsNothing);
      expect(find.byIcon(Icons.check), findsOneWidget);
    },
  );
}

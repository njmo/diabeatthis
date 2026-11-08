import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/meal_start/meal_start_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final layout in [
    (const Size(800, 900), .9),
    (const Size(800, 600), .9),
    (const Size(430, 800), .75),
    (const Size(430, 700), .75),
  ]) {
    testWidgets(
      'keyboard inset changes preserve the focused field and its text: $layout',
      (tester) async {
        tester.view.physicalSize = layout.$1;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final inset = ValueNotifier(0.0);
        final focus = FocusNode();
        final text = TextEditingController();
        addTearDown(inset.dispose);
        addTearDown(focus.dispose);
        addTearDown(text.dispose);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ValueListenableBuilder<double>(
                valueListenable: inset,
                builder: (context, bottom, _) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(viewInsets: EdgeInsets.only(bottom: bottom)),
                  child: MealStartSheet(
                    maxHeightFactor: layout.$2,
                    title: 'Decision',
                    subtitle: '',
                    body: TextField(focusNode: focus, controller: text),
                    actions: FilledButton(
                      onPressed: () {},
                      child: const Text('Send'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'Keep this message');
        await tester.pump();
        final original = tester.state(find.byType(EditableText));
        expect(focus.hasFocus, isTrue);
        inset.value = 280;
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(EditableText)), same(original));
        expect(focus.hasFocus, isTrue);
        expect(text.text, 'Keep this message');
        expect(tester.takeException(), isNull);
        inset.value = 0;
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(EditableText)), same(original));
        expect(focus.hasFocus, isTrue);
        expect(text.text, 'Keep this message');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('tall keyboard keeps a long header and both actions reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final inset = ValueNotifier(0.0);
    final focus = FocusNode();
    final text = TextEditingController();
    addTearDown(inset.dispose);
    addTearDown(focus.dispose);
    addTearDown(text.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ValueListenableBuilder<double>(
            valueListenable: inset,
            builder: (context, bottom, _) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(viewInsets: EdgeInsets.only(bottom: bottom)),
              child: MealStartSheet(
                title: 'A long decision title with context',
                subtitle:
                    'A subtitle with enough context to occupy space in the header.',
                body: TextField(focusNode: focus, controller: text),
                actions: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      onPressed: () {},
                      child: const Text('First action'),
                    ),
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Second action'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Caregiver note');
    await tester.pump();
    final original = tester.state(find.byType(EditableText));
    inset.value = 400;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.state(find.byType(EditableText)), same(original));
    expect(focus.hasFocus, isTrue);
    expect(text.text, 'Caregiver note');
    await tester.scrollUntilVisible(
      find.text('Second action'),
      80,
      scrollable: find
          .descendant(
            of: find.byType(MealStartSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Second action').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

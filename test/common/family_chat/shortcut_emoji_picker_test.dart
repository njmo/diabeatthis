import 'package:diabeatthis/common/family_chat/presentation/shortcut_emoji_picker.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'all emoji supports Polish aliases and preserves a joined Unicode emoji',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Otwórz'),
                onPressed: () async {
                  selected = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const ShortcutEmojiPicker(selected: '💬'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Otwórz'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('emoji-🎒')), findsOneWidget);
      await tester.tap(find.text('Wszystkie emoji'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'telefon');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('emoji-📞')), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Picker must fit above the keyboard',
      );
      await tester.enterText(find.byType(TextField), '👨‍👩‍👧‍👦');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('emoji-👨‍👩‍👧‍👦')));
      await tester.pumpAndSettle();
      expect(selected, '👨‍👩‍👧‍👦');
      expect(tester.takeException(), isNull);
    },
  );
}

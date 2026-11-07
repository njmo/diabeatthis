import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/presentation/dashboard/family_sync_ribbon.dart';
import 'package:diabeatthis/common/presentation/dashboard/nightscout_panel_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'sync state never moves timestamp readings or changes panel height',
    (tester) async {
      Future<void> render(bool busy, bool failed) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: NightscoutPanelView(
                syncRibbon: FamilySyncRibbon(
                  busy: busy,
                  failed: failed,
                  ready: true,
                ),
                lastUpdate: '4 min',
                readings: const SizedBox(
                  key: ValueKey('readings'),
                  height: 250,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await render(false, false);
      final age = tester.getTopLeft(find.text('4 min'));
      final reading = tester.getTopLeft(find.byKey(const ValueKey('readings')));
      final size = tester.getSize(find.byType(Card));
      for (final state in [(true, false), (false, true), (false, false)]) {
        await render(state.$1, state.$2);
        expect(tester.getTopLeft(find.text('4 min')), age);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('readings'))),
          reading,
        );
        expect(tester.getSize(find.byType(Card)), size);
        expect(tester.takeException(), isNull);
      }
    },
  );
}

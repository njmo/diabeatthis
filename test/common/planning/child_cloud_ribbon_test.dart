import 'package:diabeatthis/common/family_sync/family_mirror_status.dart';
import 'package:diabeatthis/common/family_sync/presentation/child_family_cloud_ribbon.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/presentation/dashboard/family_sync_ribbon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final enabled in [false, true]) {
    testWidgets(
      'offline child indicator only appears with family sharing enabled=$enabled',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              childFamilyCloudStateProvider.overrideWith(
                (_) => Stream.value(
                  FamilyCloudState(
                    enabled: enabled,
                    status: FamilyMirrorStatus.failed,
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: ChildFamilyCloudRibbon()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(FamilySyncRibbon),
          enabled ? findsOneWidget : findsNothing,
        );
        expect(
          find.byIcon(Icons.person_off_outlined),
          enabled ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

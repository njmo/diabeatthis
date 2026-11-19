import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/presentation/dashboard/family_sync_ribbon.dart';
import 'package:diabeatthis/common/presentation/dashboard/nightscout_panel_view.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/compact_loop_glucose_chart.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_glucose_reading.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/mini_glucose_chart.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/responsive_glucose_chart.dart';
import 'package:diabeatthis/features/low_treatment/presentation/widgets/low_treatment_suggestion_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sync status is inside chart header below the glucose value', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: NightscoutPanelView(
                lastUpdate: '2 min',
                syncRibbon: const FamilySyncRibbon(
                  compact: true,
                  busy: false,
                  failed: true,
                  ready: true,
                ),
                readings: DashboardGlucoseReading(
                  value: 123,
                  color: Colors.green,
                  trendIcon: null,
                  showDeviceCards: false,
                  readings: [
                    Glucose(
                      externalId: null,
                      source: GlucoseSource.cloud,
                      date: DateTime.now(),
                      sgv: 123,
                      direction: 'Flat',
                    ),
                  ],
                ),
                footer: LowTreatmentSuggestionCard(
                  carbsReq: 10,
                  carbsReqWithin: 15,
                  onAdd: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final sync = find.byType(FamilySyncRibbon);
    expect(sync, findsOneWidget);
    expect(
      tester.getTopLeft(sync).dy,
      greaterThan(tester.getTopLeft(find.text('123')).dy),
    );
    expect(
      tester.getBottomLeft(sync).dy,
      lessThan(tester.getTopLeft(find.byType(CompactLoopGlucoseChart)).dy),
    );
    expect(find.text('Glukoza & Predykcja Loop'), findsNothing);
    expect(
      tester.getTopLeft(find.byType(LowTreatmentSuggestionCard)).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(CompactLoopGlucoseChart)).dy),
    );
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 420.0, 600.0]) {
    testWidgets(
      'chart scales with panel and ribbon content is vertically centered at $width',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: width,
                    child: NightscoutPanelView(
                      lastUpdate: '4 min',
                      syncRibbon: const FamilySyncRibbon(
                        busy: false,
                        failed: false,
                        ready: true,
                      ),
                      readings: const DashboardGlucoseReading(
                        value: 123,
                        color: Colors.green,
                        trendIcon: null,
                        readings: [],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final available = tester
            .getSize(find.byType(ResponsiveGlucoseChart))
            .width;
        final chart = tester.getSize(find.byType(MiniGlucoseChart));
        expect(
          chart.width - MiniGlucoseChart.axisWidth - MiniGlucoseChart.axisGap,
          closeTo(available * .8, .01),
        );
        final ribbon = tester.getRect(find.byType(FamilySyncRibbon));
        final label = tester.getRect(find.text('Child’s data synced'));
        expect(label.center.dy, closeTo(ribbon.center.dy, .01));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

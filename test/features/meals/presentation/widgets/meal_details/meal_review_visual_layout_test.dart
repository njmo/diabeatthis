import 'dart:io';
import 'dart:ui' as ui;

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/meals/common/widgets/meal_comparison_bar.dart';
import 'package:diabeatthis/features/meals/data/models/meal_analysis_data.dart';
import 'package:diabeatthis/features/meals/presentation/controllers/meal_details_controller.dart';
import 'package:diabeatthis/features/meals/presentation/screens/meal_page.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_basic_info_section.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_snapshot_comparison_row.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_technical_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_review_test.dart' show ReviewTestController;

void main() {
  // Optional local visual artifacts; normal CI runs need no fonts or output path.
  final captureDirectory = Platform.environment['MEAL_REVIEW_CAPTURE_DIR'];
  setUpAll(() async {
    final fontDirectory = Platform.environment['MEAL_REVIEW_FONT_DIR'];
    if (captureDirectory == null || fontDirectory == null) return;
    final font = FontLoader('Roboto')
      ..addFont(
        File(
          '$fontDirectory/Roboto-Regular.ttf',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File(
          '$fontDirectory/MaterialIcons-Regular.otf',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    await icons.load();
  });

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (captureDirectory == null) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File(
        '$captureDirectory/$name.png',
      ).writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final dark in [false, true]) {
    testWidgets(
      'advanced chapters retain technical records in ${dark ? "dark" : "light"} mode',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 1200);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mealDetailsControllerProvider(
                1,
              ).overrideWith(() => ReviewTestController()),
            ],
            child: MaterialApp(
              locale: const Locale('pl'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
                fontFamily: 'Roboto',
              ),
              home: RepaintBoundary(key: key, child: const MealPage(mealId: 1)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture(tester, key, 'meal-basic-${dark ? "dark" : "light"}');
        await tester.tap(find.text('Zaawansowany'));
        await tester.pumpAndSettle();
        for (final title in [
          'Przebieg glikemii',
          'Co mogło mieć znaczenie',
          'Co zostało zjedzone',
          'Decyzje i ich przebieg',
        ]) {
          expect(find.text(title), findsOneWidget);
        }
        expect(find.byType(MealBasicInfoSection), findsNothing);
        await tester.ensureVisible(find.byType(MealTechnicalSection));
        await tester.pumpAndSettle();
        await capture(tester, key, 'meal-advanced-${dark ? "dark" : "light"}');
        await tester.tap(find.text('Szczegóły zapisu'));
        await tester.pumpAndSettle();
        expect(find.byType(MealBasicInfoSection), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'planned and eaten bars share a scale and fit enlarged text $scale',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 900);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('pl'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(fontFamily: 'Roboto'),
            home: RepaintBoundary(
              key: key,
              child: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: const [
                          MealSnapshotComparisonRow(
                            row: MealSnapshotComparisonRowData(
                              label: 'Węglowodany',
                              plannedValue: 30,
                              consumedValue: 45,
                              unit: 'g',
                            ),
                          ),
                          MealSnapshotComparisonRow(
                            row: MealSnapshotComparisonRowData(
                              label: 'Białko',
                              plannedValue: 20,
                              consumedValue: null,
                              unit: 'g',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final bars = tester
            .widgetList<MealComparisonBar>(find.byType(MealComparisonBar))
            .toList();
        expect(bars[0].maximum, 45);
        expect(bars[1].maximum, 45);
        expect(bars[0].value, 30);
        expect(bars[1].value, 45);
        expect(bars[3].value, isNull);
        expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
        expect(tester.takeException(), isNull);
        await capture(tester, key, 'meal-portions-$scale');
      },
    );
  }
}

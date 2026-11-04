import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_nutrition.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_assignment_tile.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_reference_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;

Widget harness(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets(
    'reference editor prefills AI portion macros and converts US carbs to EU once',
    (tester) async {
      await tester.pumpWidget(
        harness(
          const MealPhotoReferenceEditor(
            name: 'Herb sauce',
            initialNutrition: MealPhotoNutrition(
              carbs: 8,
              fiber: 2,
              fat: 7,
              protein: 1,
              carbsLabelMode: CarbsLabelMode.nonEu,
            ),
          ),
        ),
      );
      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields.map((field) => field.controller!.text).toList(), [
        '6.0',
        '6.70',
      ]);
      final split = tester
          .widgetList<Slider>(find.byType(Slider))
          .singleWhere((slider) => slider.divisions == 20);
      expect(split.value, closeTo(63 / 67, 1e-12));
    },
  );

  testWidgets(
    'unmatched item offers direct reference acceptance and matched alternatives are clear',
    (tester) async {
      final source = const MealPhotoProposalParser()
          .parse(
            fixtures.proposal(
              item: fixtures.component('sauce', kind: 'proposed_reference'),
            ),
          )
          .itemized
          .single;
      var accepted = false;
      await tester.pumpWidget(
        harness(
          MealPhotoAssignmentTile(
            item: MealPhotoReviewItem.fromProposal(source),
            allowProduct: false,
            onAssign: () {},
            onReference: () => accepted = true,
          ),
        ),
      );
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept estimated reference'));
      await tester.pumpAndSettle();
      expect(accepted, isTrue);
      await tester.pumpWidget(
        harness(
          MealPhotoAssignmentTile(
            item: MealPhotoReviewItem.fromProposal(
              source,
            ).assign(fixtures.candidate.withMatchCount(3)),
            onAssign: () {},
            onReference: () {},
          ),
        ),
      );
      expect(find.text(fixtures.candidate.name), findsOneWidget);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Choose another product'), findsOneWidget);
    },
  );
}

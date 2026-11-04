import 'package:diabeatthis/common/ingredient_catalog/widgets/ingredient_catalog_picker.dart';
import 'package:diabeatthis/common/ingredient_catalog/widgets/ingredient_catalog_results.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_assignment_tile.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_ingredient_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;
import 'meal_photo_reference_prefill_test.dart' show harness;

void main() {
  testWidgets(
    'acceptance visibly confirms reference and preserves access to the matched product',
    (tester) async {
      final source = const MealPhotoProposalParser()
          .parse(
            fixtures.proposal(
              item: fixtures.component('beets', kind: 'proposed_reference'),
            ),
          )
          .itemized
          .single;
      var item = MealPhotoReviewItem.fromProposal(
        source,
      ).assign(fixtures.candidate.withMatchCount(3));
      await tester.pumpWidget(
        harness(
          StatefulBuilder(
            builder: (context, setState) => MealPhotoAssignmentTile(
              item: item,
              onAssign: () {},
              onReference: () => setState(() => item = item.acceptReference()),
            ),
          ),
        ),
      );
      expect(find.text('Choose another product'), findsNothing);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Choose another product'), findsOneWidget);
      await tester.tap(find.text('Accept estimated reference'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(item.referenceAccepted, isTrue);
      expect(find.text('Reference accepted'), findsOneWidget);
      expect(find.text('Assign product'), findsNothing);
      expect(find.text('Choose another product'), findsOneWidget);
      expect(item.suggestedProduct?.key, fixtures.candidate.key);
      expect(
        tester
            .widget<PopupMenuItem<MealPhotoIngredientAction>>(
              find.widgetWithText(
                PopupMenuItem<MealPhotoIngredientAction>,
                'Reference accepted',
              ),
            )
            .enabled,
        isFalse,
      );
    },
  );

  testWidgets(
    'unassigned product picker opens empty without redundant name or arbitrary results',
    (tester) async {
      await tester.pumpWidget(
        harness(const IngredientCatalogPicker(searchOnly: true)),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.byType(IngredientCatalogResults), findsNothing);
    },
  );
}

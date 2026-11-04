import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_selection_origin.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;
import 'meal_photo_reference_prefill_test.dart' show harness;

void main() {
  testWidgets(
    'automatic and manual product choices are distinguished from reference choices',
    (tester) async {
      final source = const MealPhotoProposalParser()
          .parse(
            fixtures.proposal(
              item: fixtures.component('sauce', kind: 'proposed_reference'),
            ),
          )
          .itemized
          .single;
      final automatic = MealPhotoReviewItem.fromProposal(
        source,
      ).assign(fixtures.candidate, method: MealPhotoSelectionMethod.automatic);
      await tester.pumpWidget(
        harness(MealPhotoSelectionOrigin(item: automatic)),
      );
      expect(
        find.text('Standard ingredient · Automatically selected'),
        findsOneWidget,
      );
      final manual = automatic.assign(fixtures.candidate);
      await tester.pumpWidget(harness(MealPhotoSelectionOrigin(item: manual)));
      expect(
        find.text('Standard ingredient · Manually selected'),
        findsOneWidget,
      );
      final reference = manual.acceptReference();
      await tester.pumpWidget(
        harness(MealPhotoSelectionOrigin(item: reference)),
      );
      expect(find.text('AI reference · Manually selected'), findsOneWidget);
      final edited = reference.withManualReference(source.referenceNutrition!);
      await tester.pumpWidget(harness(MealPhotoSelectionOrigin(item: edited)));
      expect(find.text('Manual reference · Manually selected'), findsOneWidget);
      expect(
        automatic
            .adjust(
              grams: 190,
              quantityConfidence: .5,
              nutritionConfidence: .75,
              reviewed: false,
            )
            .selectionMethod,
        MealPhotoSelectionMethod.automatic,
      );
    },
  );
}

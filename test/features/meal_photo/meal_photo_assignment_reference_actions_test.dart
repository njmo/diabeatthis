import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_assignment_tile.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;
import 'meal_photo_reference_prefill_test.dart' show harness;

void main() {
  testWidgets(
    'matched products do not hide accepting the original AI reference or adding a reference',
    (tester) async {
      final proposal = const MealPhotoProposalParser().parse(
        fixtures.proposal(
          item: fixtures.component('sauce', kind: 'proposed_reference'),
        ),
      );
      final item = MealPhotoReviewItem.fromProposal(
        proposal.itemized.single,
      ).assign(fixtures.candidate.withMatchCount(3));
      var accepted = false;
      var created = false;
      await tester.pumpWidget(
        harness(
          MealPhotoAssignmentTile(
            item: item,
            onAssign: () {},
            onReference: () => accepted = true,
            onCreateReference: () => created = true,
          ),
        ),
      );
      expect(find.text('Choose another product'), findsNothing);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Choose another product'), findsOneWidget);
      expect(find.text('Accept estimated reference'), findsOneWidget);
      expect(find.text('Edit reference values'), findsOneWidget);
      await tester.tap(find.text('Accept estimated reference'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit reference values'));
      await tester.pumpAndSettle();
      expect(accepted, isTrue);
      expect(created, isTrue);
      expect(item.referenceNutrition, same(item.proposal.referenceNutrition));
    },
  );

  testWidgets(
    'reference creation is available directly when the model supplied no macros',
    (tester) async {
      final proposal = const MealPhotoProposalParser().parse(
        fixtures.proposal(),
      );
      var created = false;
      await tester.pumpWidget(
        harness(
          MealPhotoAssignmentTile(
            item: MealPhotoReviewItem.fromProposal(proposal.itemized.single),
            onAssign: () {},
            onReference: () {},
            onCreateReference: () => created = true,
          ),
        ),
      );
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Assign product'), findsOneWidget);
      expect(find.text('Accept estimated reference'), findsNothing);
      await tester.tap(find.text('Add as reference'));
      expect(created, isTrue);
    },
  );
}

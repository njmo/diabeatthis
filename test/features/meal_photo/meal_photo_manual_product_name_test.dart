import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_candidate.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_assignment_tile.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_confirmation_tile.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;
import 'meal_photo_reference_prefill_test.dart' show harness;

void main() {
  testWidgets(
    'manual product correction replaces AI label in review and summary without changing source',
    (tester) async {
      final row = fixtures.component('sauce', kind: 'proposed_reference')
        ..['name'] = 'Sos pieczarkowy';
      final source = const MealPhotoProposalParser()
          .parse(fixtures.proposal(item: row))
          .itemized
          .single;
      final product = MealPhotoCandidate(
        identity: fixtures.candidate.identity,
        name: 'Sos ziołowy',
        nutritionPer100g: fixtures.candidate.nutritionPer100g,
      );
      final item = MealPhotoReviewItem.fromProposal(source).assign(product);
      expect(item.displayName, 'Sos ziołowy');
      expect(item.proposal.name, 'Sos pieczarkowy');
      await tester.pumpWidget(
        harness(
          MealPhotoAssignmentTile(
            item: item,
            onAssign: () {},
            onReference: () {},
          ),
        ),
      );
      expect(find.text('Sos ziołowy'), findsOneWidget);
      expect(find.text('Sos pieczarkowy'), findsNothing);
      await tester.pumpWidget(harness(MealPhotoConfirmationTile(item: item)));
      expect(find.text('Sos ziołowy'), findsOneWidget);
      expect(find.text('Sos pieczarkowy'), findsNothing);
    },
  );
}

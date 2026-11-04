import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_confirmation_tile.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_selection_origin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;
import 'meal_photo_reference_prefill_test.dart' show harness;

void main() {
  testWidgets(
    'summary keeps name grams and provenance without expandable content',
    (tester) async {
      final item = MealPhotoReviewItem.fromProposal(
        const MealPhotoProposalParser().parse(fixtures.proposal()).reference,
      ).acceptReference();
      await tester.pumpWidget(harness(MealPhotoConfirmationTile(item: item)));
      expect(find.text(item.displayName), findsOneWidget);
      expect(find.text('150 g'), findsOneWidget);
      expect(find.byType(MealPhotoSelectionOrigin), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);
      expect(find.byIcon(Icons.expand_more), findsNothing);
    },
  );
}

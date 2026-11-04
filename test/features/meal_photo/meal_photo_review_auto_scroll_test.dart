import 'dart:convert';

import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_ingredient_review_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;
import 'meal_photo_reference_prefill_test.dart' show harness;

void main() {
  testWidgets(
    'confirming each portion reveals the next card without a manual scroll',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final raw = jsonDecode(fixtures.proposal()) as Map<String, dynamic>;
      raw['itemized'] = [
        for (final id in ['first', 'second', 'last'])
          fixtures.component(id, kind: 'proposed_reference'),
      ];
      var items = const MealPhotoProposalParser()
          .parse(jsonEncode(raw))
          .itemized
          .map(
            (item) => MealPhotoReviewItem.fromProposal(item).acceptReference(),
          )
          .toList();
      await tester.pumpWidget(
        harness(
          StatefulBuilder(
            builder: (context, update) => SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 250),
                  MealPhotoIngredientReviewList(
                    items: items,
                    builder: (item, onConfirmed) => SizedBox(
                      height: 280,
                      child: Column(
                        children: [
                          Text('Active ${item.proposal.id}'),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              update(() {
                                items = items
                                    .map(
                                      (other) =>
                                          other.proposal.id == item.proposal.id
                                          ? other.adjust(
                                              grams: 150,
                                              quantityConfidence: .5,
                                              nutritionConfidence: .75,
                                              reviewed: true,
                                            )
                                          : other,
                                    )
                                    .toList();
                              });
                              onConfirmed();
                            },
                            child: Text('Confirm ${item.proposal.id}'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 400),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Confirm first'));
      await tester.tap(find.text('Confirm first'));
      await tester.pumpAndSettle();
      for (final id in ['second', 'last']) {
        expect(tester.getTopLeft(find.text('Active $id')).dy, closeTo(0, 1));
        final confirm = find.text('Confirm $id');
        expect(tester.getBottomRight(confirm).dy, lessThan(500));
        await tester.tap(confirm);
        await tester.pumpAndSettle();
      }
      expect(items.every((item) => item.reviewed), isTrue);
      expect(find.textContaining('Active'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

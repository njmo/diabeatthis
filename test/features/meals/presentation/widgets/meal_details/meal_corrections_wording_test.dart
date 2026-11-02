import 'package:diabeatthis/common/l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets('corrections separate delivery count from total insulin', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Builder(
          builder: (context) => Column(
            children: [
              Text(context.lang.mealReviewCorrectionsValue(7, '1,15')),
              Text(context.lang.mealReviewCorrectionsValue(1, '0,5')),
              Text(context.lang.mealReviewCorrectionsValue(2, '0,8')),
              Text(context.lang.mealReviewCorrectionsValue(0, '0')),
            ],
          ),
        ),
      ),
    );
    expect(find.text('7 podań · łącznie 1,15 j.'), findsOneWidget);
    expect(find.text('1 podanie · łącznie 0,5 j.'), findsOneWidget);
    expect(find.text('2 podania · łącznie 0,8 j.'), findsOneWidget);
    expect(find.text('0 podań · łącznie 0 j.'), findsOneWidget);
  });
}

import 'dart:async';

import 'package:diabeatthis/common/ingredient_catalog/widgets/ingredient_catalog_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'scanner sits to the right of search and prevents duplicate scans',
    (tester) async {
      final completion = Completer<void>();
      var scans = 0;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: IngredientCatalogPicker(
              searchOnly: true,
              onScanBarcode: (_) async {
                scans++;
                await completion.future;
              },
            ),
          ),
        ),
      );
      final scan = find.byTooltip('Skanuj kod');
      expect(
        tester.getCenter(scan).dx,
        greaterThan(tester.getCenter(find.byType(TextField)).dx),
      );
      await tester.tap(scan);
      await tester.pump();
      await tester.tap(scan);
      expect(scans, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      completion.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

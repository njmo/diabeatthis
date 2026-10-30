import 'package:diabeatthis/common/widgets/compact_category_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'both categories remain reachable on a narrow screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              appBar: AppBar(
                title: const Text(
                  'Historia',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  CompactCategorySelector(
                    labels: const ['Posiłki', 'Aktywności'],
                    icons: const [Icons.restaurant, Icons.directions_run],
                    selectedIndex: 0,
                    onSelected: (index) => selected = index,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Aktywności'));
      expect(selected, 1);
      await tester.tap(find.byTooltip('Posiłki'));
      expect(selected, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

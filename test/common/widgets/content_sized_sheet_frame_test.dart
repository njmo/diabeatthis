import 'package:diabeatthis/common/widgets/keyboard_aware_sheet_frame.dart';
import 'package:diabeatthis/common/widgets/sheet_content_height_request.dart';
import 'package:diabeatthis/common/widgets/sheet_content_section_reporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget measuredSheet(double height, {double keyboard = 0}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(800, 600),
      viewInsets: EdgeInsets.only(bottom: keyboard),
    ),
    child: Scaffold(
      resizeToAvoidBottomInset: false,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: KeyboardAwareSheetFrame(
          child: Scaffold(
            appBar: AppBar(title: const Text('Photo')),
            body: SingleChildScrollView(
              child: SheetContentSectionReporter(
                section: SheetContentSection.body,
                child: SizedBox(height: height),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'compact content removes unused sheet height and grows when content changes',
    (tester) async {
      await tester.pumpWidget(measuredSheet(160));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Scaffold).last).height, 216);
      await tester.pumpWidget(measuredSheet(300));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Scaffold).last).height, 356);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'long content is bounded and scrolls instead of growing beyond screen',
    (tester) async {
      await tester.pumpWidget(measuredSheet(1200));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Scaffold).last).height, 540);
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('keyboard bounds the content-sized sheet without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(measuredSheet(500, keyboard: 250));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Scaffold).last).height, 290);
    expect(tester.takeException(), isNull);
  });
}

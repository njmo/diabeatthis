import 'package:diabeatthis/common/widgets/keyboard_aware_sheet_frame.dart';
import 'package:diabeatthis/common/widgets/sheet_content_height_request.dart';
import 'package:diabeatthis/common/widgets/sheet_content_section_reporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'footer transitions do not retain old height or count safe-area padding twice',
    (tester) async {
      var footer = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 600),
              padding: EdgeInsets.only(bottom: 24),
            ),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: Align(
                alignment: Alignment.bottomCenter,
                child: KeyboardAwareSheetFrame(
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      return Scaffold(
                        appBar: AppBar(title: const Text('Photo')),
                        body: const SingleChildScrollView(
                          child: SheetContentSectionReporter(
                            section: SheetContentSection.body,
                            child: SizedBox(height: 100),
                          ),
                        ),
                        bottomNavigationBar: SheetContentSectionReporter(
                          section: SheetContentSection.footer,
                          child: footer
                              ? const SafeArea(
                                  minimum: EdgeInsets.all(16),
                                  child: SizedBox(height: 48),
                                )
                              : const SizedBox.shrink(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Scaffold).last).height, 244);
      update(() => footer = false);
      await tester.pump();
      update(() => footer = true);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Scaffold).last).height, 244);
      update(() => footer = false);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Scaffold).last).height, 180);
      expect(tester.takeException(), isNull);
    },
  );
}

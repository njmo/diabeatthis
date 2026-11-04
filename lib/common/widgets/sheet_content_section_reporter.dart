import 'package:flutter/widgets.dart';

import 'sheet_content_height_request.dart';
import 'size_reporter.dart';

class SheetContentSectionReporter extends StatelessWidget {
  const SheetContentSectionReporter({
    super.key,
    required this.section,
    required this.child,
  });
  final SheetContentSection section;
  final Widget child;
  @override
  Widget build(BuildContext context) => SizeReporter(
    onSizeChanged: (size) {
      if (context.mounted) {
        SheetContentHeightRequest(section, size.height).dispatch(context);
      }
    },
    child: child,
  );
}

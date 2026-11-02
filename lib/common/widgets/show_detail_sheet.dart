import 'package:flutter/material.dart';

import 'keyboard_aware_sheet_frame.dart';

Future<void> showDetailSheet({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheetContext) => KeyboardAwareSheetFrame(
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(title),
        actions: [
          IconButton(
            tooltip: MaterialLocalizations.of(sheetContext).closeButtonTooltip,
            onPressed: () => Navigator.of(sheetContext).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.viewPaddingOf(sheetContext).bottom,
        ),
        child: builder(sheetContext),
      ),
    ),
  ),
);

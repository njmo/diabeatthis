import 'package:flutter/material.dart';

import '../l10n/language.dart';

Future<void> showMessageDialog({
  required BuildContext context,
  required String message,
}) => showDialog<void>(
  context: context,
  builder: (_) => MessageDialog(message: message),
);

class MessageDialog extends StatelessWidget {
  const MessageDialog({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => AlertDialog(
    content: SingleChildScrollView(child: Text(message)),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.lang.commonCloseTooltip),
      ),
    ],
  );
}

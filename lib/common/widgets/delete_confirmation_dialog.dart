import 'package:flutter/material.dart';

import '../l10n/language.dart';

Future<bool> showDeleteConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? cancelLabel,
  String? confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => DeleteConfirmationDialog(
      title: title,
      message: message,
      cancelLabel: cancelLabel ?? context.lang.commonCancel,
      confirmLabel: confirmLabel ?? context.lang.commonDelete,
    ),
  );
  return confirmed ?? false;
}

class DeleteConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;

  const DeleteConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

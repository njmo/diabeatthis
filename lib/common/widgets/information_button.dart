import 'package:flutter/material.dart';

import '../l10n/language.dart';

class InformationButton extends StatelessWidget {
  const InformationButton({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.lang.commonInformationTooltip,
    icon: Icon(icon),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.lang.commonCloseTooltip),
          ),
        ],
      ),
    ),
  );
}

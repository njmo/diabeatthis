import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/llm/local_llm_client.dart';

/// The provider message stays in the local UI, never in application logs.
class DayAiErrorDetailsButton extends StatelessWidget {
  final LlmRequestException error;
  const DayAiErrorDetailsButton({super.key, required this.error});

  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.info_outline),
    label: Text(context.lang.dayAiErrorDetails),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.lang.dayAiErrorDetails),
        content: SingleChildScrollView(child: SelectableText(error.message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.lang.dayAiClose),
          ),
        ],
      ),
    ),
  );
}

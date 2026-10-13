import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/language.dart';

class AiTextDialog extends StatelessWidget {
  final String text;
  final bool isResponse;

  const AiTextDialog({super.key, required this.text, this.isResponse = false});

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: ScaffoldMessenger(
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(
              isResponse
                  ? context.lang.dayAiShowResponse
                  : context.lang.dayAiShowInput,
            ),
            leading: CloseButton(),
            actions: [
              IconButton(
                tooltip: context.lang.dayAiCopyInput,
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isResponse
                            ? context.lang.dayAiResponseCopied
                            : context.lang.dayAiInputCopied,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(text),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

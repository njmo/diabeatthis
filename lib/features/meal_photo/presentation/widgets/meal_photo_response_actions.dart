import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/ai_text_dialog.dart';
import '../../domain/models/meal_photo_model_response.dart';

class MealPhotoResponseActions extends StatelessWidget {
  const MealPhotoResponseActions({super.key, required this.responses});
  final List<MealPhotoModelResponse> responses;

  @override
  Widget build(BuildContext context) {
    if (responses.isEmpty) return const SizedBox.shrink();
    final latest = responses.last;
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      children: [
        PopupMenuButton<MealPhotoModelResponse>(
          tooltip: context.lang.mealPhotoShowJson,
          onSelected: (response) => showDialog<void>(
            context: context,
            builder: (_) => AiTextDialog(text: response.text, isResponse: true),
          ),
          itemBuilder: (_) => responses
              .map(
                (response) => PopupMenuItem(
                  value: response,
                  child: Text(
                    '${response.stage == MealPhotoResponseStage.description ? context.lang.mealPhotoResponseDescription : context.lang.mealPhotoResponseResolution}${response.truncated ? ' · ${context.lang.mealPhotoResponsePartial}' : ''}',
                  ),
                ),
              )
              .toList(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.code),
                const SizedBox(width: 8),
                Text(context.lang.mealPhotoShowJson),
              ],
            ),
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy_outlined),
          label: Text(context.lang.mealPhotoCopyJson),
          onPressed: latest.text.isEmpty
              ? null
              : () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: latest.text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.lang.dayAiResponseCopied),
                        ),
                      );
                    }
                  } on PlatformException {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.lang.mealPhotoCopyFailed),
                        ),
                      );
                    }
                  }
                },
        ),
      ],
    );
  }
}

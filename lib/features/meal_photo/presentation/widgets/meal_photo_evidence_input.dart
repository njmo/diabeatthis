import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

/// Text and menu evidence may both be supplied; neither hides the other.
class MealPhotoEvidenceInput extends StatelessWidget {
  const MealPhotoEvidenceInput({
    super.key,
    required this.description,
    required this.menuPhotoSelected,
    required this.onMenuPhoto,
    required this.onTextChanged,
    this.busy = false,
  });
  final TextEditingController description;
  final bool menuPhotoSelected;
  final VoidCallback onMenuPhoto;
  final ValueChanged<String> onTextChanged;
  final bool busy;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.lang.mealPhotoCompositionInstruction,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: description,
            enabled: !busy,
            minLines: 1,
            maxLines: 3,
            maxLength: 4000,
            onChanged: onTextChanged,
            decoration: InputDecoration(
              labelText: context.lang.mealPhotoCompositionText,
              hintText: context.lang.mealPhotoCompositionHint,
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : onMenuPhoto,
            icon: Icon(
              menuPhotoSelected
                  ? Icons.check_circle_outline
                  : Icons.menu_book_outlined,
            ),
            label: Text(
              menuPhotoSelected
                  ? context.lang.mealPhotoCompositionMenuReady
                  : context.lang.mealPhotoCompositionMenu,
            ),
          ),
        ],
      ),
    ),
  );
}

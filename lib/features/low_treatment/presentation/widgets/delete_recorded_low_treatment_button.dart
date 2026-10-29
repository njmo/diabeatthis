import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/delete_confirmation_dialog.dart';

class DeleteRecordedLowTreatmentButton extends StatelessWidget {
  const DeleteRecordedLowTreatmentButton({
    super.key,
    required this.busy,
    required this.onDelete,
  });

  final bool busy;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: TextButton.icon(
      icon: const Icon(Icons.delete_outline),
      label: Text(context.lang.commonDelete),
      onPressed: busy
          ? null
          : () async {
              final confirmed = await showDeleteConfirmationDialog(
                context,
                title: context.lang.lowTreatmentDeleteTitle,
                message: context.lang.lowTreatmentDeleteMessage,
              );
              if (confirmed && context.mounted) await onDelete();
            },
    ),
  );
}

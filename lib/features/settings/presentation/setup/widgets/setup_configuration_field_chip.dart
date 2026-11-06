import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_configuration_field.dart';
import '../setup_labels.dart';

class SetupConfigurationFieldChip extends StatelessWidget {
  const SetupConfigurationFieldChip({super.key, required this.field});
  final SetupConfigurationField field;
  @override
  Widget build(BuildContext context) => Chip(
    avatar: const Icon(Icons.edit_note, size: 15),
    label: Text(
      context.lang.setupRequiredFieldLabel(
        context.lang.configurationFieldName(field),
      ),
      style: Theme.of(context).textTheme.labelSmall,
    ),
    visualDensity: VisualDensity.compact,
  );
}

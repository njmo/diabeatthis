import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../common/l10n/application_language.dart';
import '../../../../common/l10n/language.dart';

class ApplicationLanguageSelector extends StatelessWidget {
  const ApplicationLanguageSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ApplicationLanguage value;
  final FutureOr<void> Function(ApplicationLanguage language) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value.code,
      decoration: InputDecoration(
        labelText: context.lang.settingsLanguageFieldLabel,
      ),
      items: supportedApplicationLanguages
          .map(
            (language) => DropdownMenuItem<String>(
              value: language.code,
              child: Text(language.label(context.lang)),
            ),
          )
          .toList(),
      onChanged: (code) async {
        if (code == null) return;
        await onChanged(applicationLanguageByCode(code));
      },
    );
  }
}

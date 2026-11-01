import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../common/l10n/language.dart';

/// A settings draft field that never registers with a surrounding form.
class AiModelField extends HookWidget {
  const AiModelField({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.errorText,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: value);
    useEffect(() {
      if (controller.text != value) {
        controller.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
      return null;
    }, [value]);
    return TextField(
      controller: controller,
      enabled: enabled,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: context.lang.settingsAiModelLabel,
        errorText: errorText,
      ),
      onChanged: onChanged,
    );
  }
}

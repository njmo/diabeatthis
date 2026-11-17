import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/language.dart';
import '../pairing_code.dart';

Future<String?> showFamilyPairingCodeDialog(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (_) => const _PairingCodeDialog(),
    );

class _PairingCodeDialog extends StatefulWidget {
  const _PairingCodeDialog();
  @override
  State<_PairingCodeDialog> createState() => _PairingCodeDialogState();
}

class _PairingCodeDialogState extends State<_PairingCodeDialog> {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    if (form.currentState!.validate()) {
      Navigator.of(context).pop(controller.text.trim().toUpperCase());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.lang.familyEnterPairingCode),
    content: Form(
      key: form,
      child: TextFormField(
        controller: controller,
        autofocus: true,
        maxLength: 32,
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          TextInputFormatter.withFunction((oldValue, value) {
            if (!value.composing.isCollapsed) return value;
            String clean(String text) =>
                text.replaceAll(RegExp(r'[-\s]'), '').toUpperCase();
            final raw = clean(value.text);
            final formatted = raw.length > 4
                ? '${raw.substring(0, 4)}-${raw.substring(4)}'
                : raw;
            int offset(int position) {
              if (position < 0) return formatted.length;
              final count = clean(value.text.substring(0, position)).length;
              return count > 4 ? count + 1 : count;
            }

            return TextEditingValue(
              text: formatted,
              selection: TextSelection(
                baseOffset: offset(value.selection.baseOffset),
                extentOffset: offset(value.selection.extentOffset),
              ),
            );
          }),
        ],
        decoration: InputDecoration(
          labelText: context.lang.familyPairingCodeLabel,
          helperText: context.lang.familyPairingCodeHint,
          helperMaxLines: 2,
          errorMaxLines: 2,
        ),
        validator: (value) => isValidPairingCode(value ?? '')
            ? null
            : context.lang.familyPairingCodeInvalid,
        onFieldSubmitted: (_) => submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.lang.commonCancel),
      ),
      FilledButton(
        onPressed: submit,
        child: Text(context.lang.familyPairingCodeSubmit),
      ),
    ],
  );
}

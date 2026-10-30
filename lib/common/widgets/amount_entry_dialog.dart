import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';

import '../l10n/language.dart';

// Keep scaling by ten within the exact integer range of a double.
const _maxPreciselyRoundedAmount = 900719925474099;

class AmountEntryDialog extends HookWidget {
  const AmountEntryDialog({
    super.key,
    required this.value,
    required this.min,
    this.max,
  });

  final double value;
  final double min;
  final double? max;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final format = NumberFormat('0.#', lang.localeName);
    final controller = useTextEditingController(text: format.format(value));
    final formKey = useMemoized(() => GlobalKey<FormState>());
    useEffect(() {
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
      return null;
    }, [controller]);

    double? parse(String text) =>
        double.tryParse(text.trim().replaceAll(',', '.'));

    void submit() {
      if (formKey.currentState!.validate()) {
        Navigator.of(context).pop(parse(controller.text));
      }
    }

    return AlertDialog(
      title: Text(lang.amountEntryTitle),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(
            decimal: true,
            signed: min < 0,
          ),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: lang.addIngredientAmountTitle),
          validator: (text) {
            final amount = parse(text ?? '');
            if (amount == null ||
                !amount.isFinite ||
                amount.abs() > _maxPreciselyRoundedAmount) {
              return lang.amountEntryInvalid;
            }
            if (amount < min) {
              return lang.amountEntryMinimum(format.format(min));
            }
            if (max != null && amount > max!) {
              return lang.amountEntryMaximum(format.format(max));
            }
            return null;
          },
          onFieldSubmitted: (_) => submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(lang.commonCancel),
        ),
        FilledButton(onPressed: submit, child: Text(lang.commonConfirm)),
      ],
    );
  }
}

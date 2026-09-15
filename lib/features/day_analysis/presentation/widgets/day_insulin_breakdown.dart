import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../formatters/day_stat_formatter.dart';
import 'day_amount_breakdown.dart';

class DayInsulinBreakdown extends StatelessWidget {
  final double? basal;
  final double? boluses;
  final double? smb;
  const DayInsulinBreakdown({
    super.key,
    required this.basal,
    required this.boluses,
    required this.smb,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final format = DayStatFormatter(lang.localeName);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final manual = boluses == null || smb == null || smb! > boluses!
        ? null
        : boluses! - smb!;
    final units = format.insulin;
    return DayAmountBreakdown(
      segments: [
        (
          label: lang.dayBasalTitle,
          value: units(basal),
          amount: basal,
          color: dark ? Colors.blue.shade300 : Colors.blue.shade700,
        ),
        (
          label: lang.dayManualBoluses,
          value: units(manual),
          amount: manual,
          color: dark ? Colors.purple.shade200 : Colors.purple.shade700,
        ),
        (
          label: lang.dayCorrectionBoluses,
          value: units(smb),
          amount: smb,
          color: dark ? Colors.amber.shade300 : Colors.orange.shade800,
        ),
      ],
    );
  }
}

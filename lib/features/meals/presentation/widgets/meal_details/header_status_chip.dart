import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import 'header_status_chip_type.dart';

class HeaderStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? detail;
  final HeaderStatusChipType? type;

  const HeaderStatusChip({
    super.key,
    required this.icon,
    required this.label,
    this.detail,
    this.type,
  });

  const HeaderStatusChip.addOn({super.key})
    : icon = Icons.add_circle_outline,
      label = '',
      detail = null,
      type = HeaderStatusChipType.addOn;

  const HeaderStatusChip.lowTreatment({super.key})
    : icon = Icons.bloodtype_outlined,
      label = '',
      detail = null,
      type = HeaderStatusChipType.lowTreatment;

  const HeaderStatusChip.copied({super.key})
    : icon = Icons.content_copy,
      label = '',
      detail = null,
      type = HeaderStatusChipType.copied;

  const HeaderStatusChip.missingExtendedCarbs({super.key})
    : icon = Icons.warning_amber_rounded,
      label = '',
      detail = null,
      type = HeaderStatusChipType.missingExtendedCarbs;

  const HeaderStatusChip.waitTimeIgnored({super.key})
    : icon = Icons.fast_forward_outlined,
      label = '',
      detail = null,
      type = HeaderStatusChipType.waitTimeIgnored;

  @override
  Widget build(BuildContext context) {
    final text = _text(context.lang);
    return Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      avatar: Icon(
        icon,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
      label: Text(text),
    );
  }

  String _text(AppLocalizations lang) {
    if (type == null) {
      return detail == null ? label : '$label • $detail';
    }
    return switch (type!) {
      HeaderStatusChipType.addOn => lang.mealHeaderAddOnChip,
      HeaderStatusChipType.lowTreatment => lang.mealHeaderLowTreatmentChip,
      HeaderStatusChipType.copied => lang.mealHeaderCopiedChip,
      HeaderStatusChipType.missingExtendedCarbs =>
        lang.mealHeaderMissingExtendedCarbsChip,
      HeaderStatusChipType.waitTimeIgnored =>
        lang.mealHeaderWaitTimeIgnoredChip,
      HeaderStatusChipType.analysisPending => lang.mealHeaderAnalysisPending,
      HeaderStatusChipType.analysisInProgress =>
        lang.mealHeaderAnalysisInProgress(detail ?? ''),
      HeaderStatusChipType.analysisReady => lang.mealHeaderAnalysisReady(
        int.tryParse(detail ?? '') ?? 0,
      ),
    };
  }
}

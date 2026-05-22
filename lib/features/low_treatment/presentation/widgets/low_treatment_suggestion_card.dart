import 'package:flutter/material.dart';

class LowTreatmentSuggestionCard extends StatelessWidget {
  const LowTreatmentSuggestionCard({
    super.key,
    required this.carbsReq,
    required this.carbsReqWithin,
    required this.onAdd,
  });

  final double carbsReq;
  final int carbsReqWithin;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.onTertiaryContainer.withValues(alpha: 0.12),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
          child: Row(
            children: [
              Icon(
                Icons.local_drink_outlined,
                size: 20,
                color: colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dosłodź ${_formatCarbs(carbsReq)} g',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _sourceLabel(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Dodaj dosłodzenie',
                child: SizedBox.square(
                  dimension: 34,
                  child: Material(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onAdd,
                      child: Icon(
                        Icons.add,
                        size: 20,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sourceLabel() {
    if (carbsReqWithin > 0) {
      return 'Sugestia AAPS · w ciągu $carbsReqWithin min';
    }

    return 'Sugestia AAPS';
  }

  String _formatCarbs(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }
}

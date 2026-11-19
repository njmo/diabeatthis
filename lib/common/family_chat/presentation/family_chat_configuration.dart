import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../domain/family_chat_preferences.dart';

class FamilyChatConfiguration extends StatelessWidget {
  const FamilyChatConfiguration({
    super.key,
    required this.value,
    required this.onChanged,
    this.canChangeRetention = true,
    this.showRetentionWhenDisabled = false,
    this.canEnable = true,
    this.accountTitle,
    this.cardLayout = false,
    this.showAccount = true,
  });
  final FamilyChatPreferences value;
  final ValueChanged<FamilyChatPreferences>? onChanged;
  final bool canChangeRetention;
  final bool showRetentionWhenDisabled, canEnable;
  final String? accountTitle;
  final bool cardLayout;
  final bool showAccount;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final theme = Theme.of(context);
    Widget group(Widget child) => cardLayout
        ? Material(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: .35,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: .3),
              ),
            ),
            child: Padding(padding: const EdgeInsets.all(12), child: child),
          )
        : child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showAccount)
          group(
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: cardLayout,
              title: Text(
                accountTitle ?? lang.familyChatTitle,
                style: cardLayout ? theme.textTheme.titleSmall : null,
              ),
              subtitle: Text(
                lang.familyChatEnabledDescription,
                style: cardLayout
                    ? theme.textTheme.bodySmall?.copyWith(height: 1.35)
                    : null,
              ),
              value: value.enabled,
              onChanged: onChanged == null || !value.enabled && !canEnable
                  ? null
                  : (enabled) => onChanged!(value.copyWith(enabled: enabled)),
            ),
          ),
        if (value.enabled || showRetentionWhenDisabled) ...[
          if (cardLayout && showAccount) const SizedBox(height: 14),
          group(
            DropdownButtonFormField<ChatRetention>(
              initialValue: value.retention,
              key: ValueKey(value.retention),
              isExpanded: true,
              decoration: InputDecoration(
                labelText: lang.familyChatRetentionTitle,
                isDense: cardLayout,
                contentPadding: cardLayout
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 14)
                    : null,
              ),
              items: [
                for (final retention in ChatRetention.values)
                  DropdownMenuItem(
                    value: retention,
                    child: Text(switch (retention) {
                      ChatRetention.day => lang.familyChatRetentionDay,
                      ChatRetention.week => lang.familyChatRetentionWeek,
                      ChatRetention.month => lang.familyChatRetentionMonth,
                      ChatRetention.unlimited =>
                        lang.familyChatRetentionUnlimited,
                    }),
                  ),
              ],
              onChanged: onChanged == null || !canChangeRetention
                  ? null
                  : (retention) {
                      if (retention != null) {
                        onChanged!(value.copyWith(retention: retention));
                      }
                    },
            ),
          ),
        ],
      ],
    );
  }
}

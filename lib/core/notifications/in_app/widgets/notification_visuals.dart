import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/theme/app_design_tokens.dart';
import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_action_input_def.dart';
import '../../domain/models/notification_action_type.dart';
import '../../domain/models/notification_channel_type.dart';

/// Icon and accent shared by banners and inbox rows of one channel.
({IconData icon, Color accent}) notificationVisuals(
  BuildContext context,
  NotificationChannelType channel,
) {
  final scheme = Theme.of(context).colorScheme;
  final brightness = Theme.of(context).brightness;
  return switch (channel) {
    NotificationChannelType.meal => (
      icon: Icons.restaurant_rounded,
      accent: brightness == Brightness.dark
          ? AppColors.cobDark
          : AppColors.cobLight,
    ),
    NotificationChannelType.activity => (
      icon: Icons.directions_run_rounded,
      accent: AppColors.activity,
    ),
    NotificationChannelType.target => (
      icon: Icons.track_changes_rounded,
      accent: scheme.tertiary,
    ),
    NotificationChannelType.aapsSuggestion => (
      icon: Icons.vaccines_rounded,
      accent: AppColors.iob(brightness),
    ),
    NotificationChannelType.familyChat => (
      icon: Icons.forum_rounded,
      accent: scheme.primary,
    ),
  };
}

class NotificationChannelBadge extends StatelessWidget {
  const NotificationChannelBadge({
    super.key,
    required this.channel,
    this.size = 40,
  });

  final NotificationChannelType channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final visuals = notificationVisuals(context, channel);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: visuals.accent.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(visuals.icon, color: visuals.accent, size: size * 0.55),
    );
  }
}

typedef NotificationActionCallback =
    Future<void> Function(NotificationActionDef action, String? input);

/// The definition's buttons, in the order the system notification shows them.
/// The positive answer is emphasised, the rest stay quiet.
class NotificationActionButtons extends StatefulWidget {
  const NotificationActionButtons({
    super.key,
    required this.actions,
    required this.onAction,
    required this.dialogContext,
    this.choices = const [],
  });

  final List<NotificationActionDef> actions;

  /// Suggested answers offered in the text input dialog.
  final List<String> choices;
  final NotificationActionCallback onAction;

  /// A context below the app navigator, used to ask for text input.
  final BuildContext? Function() dialogContext;

  @override
  State<NotificationActionButtons> createState() =>
      _NotificationActionButtonsState();
}

class _NotificationActionButtonsState extends State<NotificationActionButtons> {
  bool _busy = false;

  bool _isPrimary(NotificationActionDef action) =>
      action.type == NotificationActionType.agree ||
      action.type == NotificationActionType.eating;

  Future<void> _press(NotificationActionDef action) async {
    if (_busy) return;
    // Busy from the first tap: the banner stays tappable above the input
    // dialog's barrier, so a second tap must not open another dialog.
    setState(() => _busy = true);
    try {
      String? input;
      if (action is TextNotificationActionDef) {
        final context = widget.dialogContext();
        if (context == null) return;
        input = await _askForInput(
          context,
          action.inputActionDef,
          widget.choices,
        );
        if (input == null || !mounted) return;
      }
      await widget.onAction(action, input);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final action in widget.actions)
          _isPrimary(action)
              ? FilledButton(
                  onPressed: _busy ? null : () => _press(action),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(action.label),
                )
              : TextButton(
                  onPressed: _busy ? null : () => _press(action),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(action.label),
                ),
      ],
    );
  }
}

Future<String?> _askForInput(
  BuildContext context,
  NotificationActionInputDef input,
  List<String> choices,
) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _NotificationInputDialog(input: input, choices: choices),
  );
}

class _NotificationInputDialog extends StatefulWidget {
  const _NotificationInputDialog({required this.input, required this.choices});

  final NotificationActionInputDef input;
  final List<String> choices;

  @override
  State<_NotificationInputDialog> createState() =>
      _NotificationInputDialogState();
}

class _NotificationInputDialogState extends State<_NotificationInputDialog> {
  final _controller = TextEditingController();
  int _minutes = 30;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.input.minuteStep;
    if (step != null) {
      return AlertDialog(
        title: Text(widget.input.title),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _minutes <= step
                  ? null
                  : () => setState(() => _minutes -= step),
              child: Text('−$step'),
            ),
            Text('$_minutes'),
            TextButton(
              onPressed: _minutes >= 1440
                  ? null
                  : () => setState(() => _minutes += step),
              child: Text('+$step'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.lang.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('$_minutes'),
            child: Text(context.lang.mealDecisionDefer),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(widget.input.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.choices.isNotEmpty) ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final choice in widget.choices)
                  ActionChip(
                    label: Text(choice),
                    onPressed: () => Navigator.of(context).pop(choice),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          TextField(
            controller: _controller,
            autofocus: widget.choices.isEmpty,
            decoration: InputDecoration(hintText: widget.input.placeholderText),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.lang.commonCancel),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => FilledButton(
            onPressed: _controller.text.trim().isEmpty ? null : _submit,
            child: Text(context.lang.notificationInputSend),
          ),
        ),
      ],
    );
  }
}

/// Reply directly below a chat notification, including its preset answers.
class NotificationInlineReply extends StatefulWidget {
  const NotificationInlineReply({
    super.key,
    required this.choices,
    required this.onReply,
    this.onEditing,
  });

  final List<String> choices;
  final Future<void> Function(String) onReply;
  final VoidCallback? onEditing;

  @override
  State<NotificationInlineReply> createState() =>
      _NotificationInlineReplyState();
}

class _NotificationInlineReplyState extends State<NotificationInlineReply> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _expanded = false;
  bool _sending = false;

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String input) async {
    final text = input.trim();
    if (_sending || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.onReply(text);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.choices.isNotEmpty)
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final choice in widget.choices)
                ActionChip(
                  label: Text(choice),
                  onPressed: _sending ? null : () => _submit(choice),
                ),
            ],
          ),
        if (!_expanded)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: _sending
                  ? null
                  : () {
                      setState(() => _expanded = true);
                      widget.onEditing?.call();
                      _focusNode.requestFocus();
                    },
              child: Text(context.lang.notificationWriteReplyAction),
            ),
          )
        else
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: !_sending,
              textInputAction: TextInputAction.send,
              onSubmitted: _submit,
              decoration: InputDecoration(
                hintText: context.lang.familyChatComposerHintChild,
                isDense: true,
                filled: true,
                fillColor: scheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                suffixIcon: IconButton(
                  tooltip: context.lang.notificationInputSend,
                  onPressed: _sending || _controller.text.trim().isEmpty
                      ? null
                      : () => _submit(_controller.text),
                  icon: const Icon(Icons.send_rounded),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

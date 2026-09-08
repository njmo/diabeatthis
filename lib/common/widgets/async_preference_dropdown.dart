import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Saves immediately and restores the displayed value when persistence fails.
class AsyncPreferenceDropdown<T> extends HookWidget {
  final AsyncValue<T> value;
  final String label;
  final List<DropdownMenuItem<T>> items;
  final Future<void> Function(T value) onSave;
  final String loadError;
  final String saveError;

  const AsyncPreferenceDropdown({
    super.key,
    required this.value,
    required this.label,
    required this.items,
    required this.onSave,
    required this.loadError,
    required this.saveError,
  });

  @override
  Widget build(BuildContext context) {
    final saving = useState(false);
    final revision = useState(0);
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text(loadError),
      data: (current) => DropdownButtonFormField<T>(
        key: ValueKey((current, revision.value)),
        initialValue: current,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: items,
        onChanged: saving.value
            ? null
            : (selected) async {
                if (selected == null || selected == current) return;
                saving.value = true;
                try {
                  await onSave(selected);
                } catch (_) {
                  if (context.mounted) {
                    revision.value++;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(saveError)));
                  }
                } finally {
                  if (context.mounted) saving.value = false;
                }
              },
      ),
    );
  }
}

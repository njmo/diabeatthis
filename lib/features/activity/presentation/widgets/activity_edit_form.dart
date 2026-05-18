import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class ActivityEditValues {
  final String name;
  final int? durationMinutes;

  const ActivityEditValues({required this.name, required this.durationMinutes});
}

class ActivityEditForm extends HookWidget {
  final String name;
  final int? durationMinutes;
  final bool isSaving;
  final ValueChanged<ActivityEditValues> onSave;
  final VoidCallback onCancel;

  const ActivityEditForm({
    super.key,
    required this.name,
    required this.durationMinutes,
    required this.isSaving,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final nameController = useTextEditingController(text: name);
    final durationController = useTextEditingController(
      text: durationMinutes?.toString() ?? '',
    );
    final hasPlannedDuration = useState(durationMinutes != null);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: nameController,
                enabled: !isSaving,
                maxLength: 30,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 2) {
                    return 'Podaj nazwę aktywności';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Nazwa aktywności',
                  border: OutlineInputBorder(),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: hasPlannedDuration.value,
                onChanged: isSaving
                    ? null
                    : (value) {
                        hasPlannedDuration.value = value ?? false;
                      },
                title: const Text('Aktywność ma start i koniec'),
                subtitle: const Text('Odznacz, jeśli kończysz ją ręcznie'),
              ),
              if (hasPlannedDuration.value) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: durationController,
                  enabled: !isSaving,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  validator: (value) {
                    final duration = int.tryParse(value?.trim() ?? '');
                    if (duration == null || duration <= 0) {
                      return 'Podaj czas w minutach';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Czas trwania w minutach',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSaving ? null : onCancel,
                    child: const Text('Anuluj'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: isSaving
                        ? null
                        : () {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            onSave(
                              ActivityEditValues(
                                name: nameController.text.trim(),
                                durationMinutes: hasPlannedDuration.value
                                    ? int.parse(durationController.text.trim())
                                    : null,
                              ),
                            );
                          },
                    icon: isSaving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Zapisz'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

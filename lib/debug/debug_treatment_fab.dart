import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers/app_event_router_provider.dart';
import '../app/providers/app_foreground_bridge_provider.dart';
import 'debug_treatment_event.dart';

class DebugTreatmentFab extends ConsumerWidget {
  const DebugTreatmentFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.small(
      heroTag: 'debug-treatment-fab',
      tooltip: 'Simulate treatment',
      onPressed: () => _open(context, ref),
      child: const Icon(Icons.science_outlined),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final event = await showDialog<DebugTreatmentEvent>(
      context: context,
      builder: (context) => const _DebugTreatmentDialog(),
    );
    if (event == null || !context.mounted) return;
    final bridge = ref.read(appForegroundBridgeProvider);
    var sent = false;
    try {
      await bridge.init();
      if (context.mounted && await bridge.isServiceRunning()) {
        if (!context.mounted) return;
        ref.read(appEventRouterProvider).send(event);
        sent = true;
      }
    } catch (_) {
      // Foreground initialization can fail when monitoring is unavailable.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? '${event.kind.label} sent to monitoring.'
              : 'Start monitoring before simulating a treatment.',
        ),
      ),
    );
  }
}

class _DebugTreatmentDialog extends StatefulWidget {
  const _DebugTreatmentDialog();

  @override
  State<_DebugTreatmentDialog> createState() => _DebugTreatmentDialogState();
}

class _DebugTreatmentDialogState extends State<_DebugTreatmentDialog> {
  final _insulin = TextEditingController();
  final _carbs = TextEditingController();
  final _minutes = TextEditingController();
  DebugTreatmentKind _kind = DebugTreatmentKind.manualBolus;
  bool _showError = false;

  @override
  void dispose() {
    _insulin.dispose();
    _carbs.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _submit() {
    final event = DebugTreatmentEvent.tryParse(
      _kind,
      insulin: _insulin.text,
      carbs: _carbs.text,
      minutes: _minutes.text,
    );
    if (event == null) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(event);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Simulate treatment'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<DebugTreatmentKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Treatment'),
            items: [
              for (final kind in DebugTreatmentKind.values)
                DropdownMenuItem(value: kind, child: Text(kind.label)),
            ],
            onChanged: (kind) => setState(() {
              _kind = kind!;
              _showError = false;
            }),
          ),
          if (_kind.hasInsulin)
            TextField(
              controller: _insulin,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: _kind == DebugTreatmentKind.calculator
                    ? 'Calculated insulin (U)'
                    : 'Insulin (U)',
              ),
            ),
          if (_kind.hasCarbs)
            TextField(
              controller: _carbs,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Carbs (g)'),
            ),
          if (_kind == DebugTreatmentKind.extendedCarbs)
            TextField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
              ),
            ),
          if (_showError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Enter valid treatment amounts.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Send')),
      ],
    );
  }
}

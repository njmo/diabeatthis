import 'package:flutter/material.dart';

class DataSourceMirrorSwitch extends StatelessWidget {
  const DataSourceMirrorSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Mirror do lokalnej bazy'),
      subtitle: const Text(
        'Zapisuj dane z chmury lokalnie, żeby później użyć ich bez sieci.',
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

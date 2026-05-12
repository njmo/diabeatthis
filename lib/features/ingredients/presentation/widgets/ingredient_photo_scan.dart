import 'package:flutter/material.dart';

class IngredientPhotoScan extends StatelessWidget {
  const IngredientPhotoScan({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PhotoStepTile(
            icon: Icons.inventory_2_outlined,
            title: 'Przód opakowania',
            subtitle: 'Nazwa produktu i producent',
          ),
          const SizedBox(height: 8),
          _PhotoStepTile(
            icon: Icons.table_chart_outlined,
            title: 'Tabela makro',
            subtitle: 'Wartości odżywcze na 100 g',
          ),
          const SizedBox(height: 12),
          Text(
            'Na razie ten krok używa przykładowego odczytu.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PhotoStepTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PhotoStepTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: colors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.pending_outlined),
    );
  }
}

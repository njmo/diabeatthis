import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/database_backup_scope.dart';
import '../../data/providers/database_backup_service_provider.dart';
import 'settings_section_card.dart';

class DatabaseSettingsSection extends ConsumerStatefulWidget {
  const DatabaseSettingsSection({super.key});

  @override
  ConsumerState<DatabaseSettingsSection> createState() =>
      _DatabaseSettingsSectionState();
}

class _DatabaseSettingsSectionState
    extends ConsumerState<DatabaseSettingsSection> {
  DatabaseBackupScope _selectedScope = DatabaseBackupScope.core;
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isClearing = false;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      icon: Icons.storage_outlined,
      title: 'Baza danych',
      subtitle: 'Eksport, import i porządkowanie lokalnych danych aplikacji.',
      children: [
        _ScopeSelector(
          value: _selectedScope,
          onChanged: (value) => setState(() => _selectedScope = value),
        ),
        const SizedBox(height: 12),
        _DatabaseActionButton(
          icon: Icons.file_upload_outlined,
          label: 'Eksportuj do pliku',
          isLoading: _isExporting,
          onPressed: _isExporting ? null : _exportDatabase,
        ),
        const SizedBox(height: 8),
        _DatabaseActionButton(
          icon: Icons.file_download_outlined,
          label: 'Importuj z pliku',
          isLoading: _isImporting,
          onPressed: _isImporting ? null : _pickAndImportDatabase,
        ),
        const SizedBox(height: 16),
        Divider(color: Theme.of(context).colorScheme.outlineVariant),
        const SizedBox(height: 8),
        _DatabaseActionButton(
          icon: Icons.cleaning_services_outlined,
          label: 'Wyczyść historię i posiłki',
          isDestructive: true,
          isLoading: _isClearing,
          onPressed: _isClearing ? null : _confirmClearHistory,
        ),
      ],
    );
  }

  Future<void> _exportDatabase() async {
    setState(() => _isExporting = true);
    try {
      final service = ref.read(databaseBackupServiceProvider);
      final file = await service.exportToFile(_selectedScope);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Eksport bazy DiabeatThis',
        ),
      );
      if (!mounted) return;
      _showSnackBar('Eksport bazy danych jest gotowy.');
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Nie udało się wyeksportować bazy danych.');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _pickAndImportDatabase() async {
    String? path;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      path = result?.files.single.path;
    } on MissingPluginException {
      if (!mounted) return;
      _showSnackBar(
        'Importer plików nie jest jeszcze dostępny. Uruchom aplikację ponownie po pełnym rebuildzie.',
      );
      return;
    }

    if (path == null) return;
    if (!path.toLowerCase().endsWith('.json')) {
      _showSnackBar('Wybierz plik eksportu w formacie JSON.');
      return;
    }

    if (!mounted) return;
    final confirmed = await _confirmImport();
    if (confirmed != true) return;

    setState(() => _isImporting = true);
    try {
      final result = await ref
          .read(databaseBackupServiceProvider)
          .importFromFile(File(path));
      if (!mounted) return;
      _showSnackBar(
        'Zaimportowano ${result.rowCount} rekordów z pliku bazy danych.',
      );
    } on FormatException {
      if (!mounted) return;
      _showSnackBar('Ten plik nie wygląda jak poprawny eksport bazy danych.');
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Nie udało się zaimportować bazy danych.');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<bool?> _confirmImport() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zaimportować bazę?'),
        content: const Text(
          'Import zastąpi aktualne dane lokalne zakresem zapisanym w pliku. '
          'Przed kontynuacją upewnij się, że masz aktualny eksport.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Importuj'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wyczyścić historię?'),
        content: const Text(
          'Usunięte zostaną posiłki, historia aktywności, analizy i zapisane '
          'snapshoty. Składniki, porcje, aktywności i szablony posiłków '
          'zostaną zachowane.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anuluj'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Wyczyść'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isClearing = true);
    try {
      await ref
          .read(databaseBackupServiceProvider)
          .clearHistoryKeepingCoreData();
      if (!mounted) return;
      _showSnackBar('Historia i posiłki zostały wyczyszczone.');
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Nie udało się wyczyścić danych.');
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ScopeSelector extends StatelessWidget {
  const _ScopeSelector({required this.value, required this.onChanged});

  final DatabaseBackupScope value;
  final ValueChanged<DatabaseBackupScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CheckboxListTile(
          value: value == DatabaseBackupScope.core,
          onChanged: (_) => onChanged(DatabaseBackupScope.core),
          contentPadding: EdgeInsets.zero,
          title: const Text('Eksportuj tylko dane bazowe'),
          subtitle: const Text(
            'Składniki, porcje, aktywności i szablony posiłków.',
          ),
        ),
        CheckboxListTile(
          value: value == DatabaseBackupScope.full,
          onChanged: (_) => onChanged(DatabaseBackupScope.full),
          contentPadding: EdgeInsets.zero,
          title: const Text('Eksportuj całą bazę'),
          subtitle: const Text('Pełna historia, posiłki, analizy i snapshoty.'),
        ),
      ],
    );
  }
}

class _DatabaseActionButton extends StatelessWidget {
  const _DatabaseActionButton({
    required this.icon,
    required this.label,
    this.isDestructive = false,
    this.isLoading = false,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = isDestructive ? colorScheme.error : null;

    return OutlinedButton.icon(
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(foregroundColor: foregroundColor),
      onPressed: onPressed,
    );
  }
}

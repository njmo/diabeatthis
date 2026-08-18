import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../common/l10n/language.dart';
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
      title: context.lang.settingsDatabaseTitle,
      subtitle: context.lang.settingsDatabaseSubtitle,
      children: [
        _ScopeSelector(
          value: _selectedScope,
          onChanged: (value) => setState(() => _selectedScope = value),
        ),
        const SizedBox(height: 12),
        _DatabaseActionButton(
          icon: Icons.file_upload_outlined,
          label: context.lang.settingsDatabaseExportButton,
          isLoading: _isExporting,
          onPressed: _isExporting ? null : _exportDatabase,
        ),
        const SizedBox(height: 8),
        _DatabaseActionButton(
          icon: Icons.file_download_outlined,
          label: context.lang.settingsDatabaseImportButton,
          isLoading: _isImporting,
          onPressed: _isImporting ? null : _pickAndImportDatabase,
        ),
        const SizedBox(height: 16),
        Divider(color: Theme.of(context).colorScheme.outlineVariant),
        const SizedBox(height: 8),
        _DatabaseActionButton(
          icon: Icons.cleaning_services_outlined,
          label: context.lang.settingsDatabaseClearButton,
          isDestructive: true,
          isLoading: _isClearing,
          onPressed: _isClearing ? null : _confirmClearHistory,
        ),
      ],
    );
  }

  Future<void> _exportDatabase() async {
    final exportSavedMessage = context.lang.settingsDatabaseExportSaved;
    final exportShareText = context.lang.settingsDatabaseExportShareText;
    final exportReadyMessage = context.lang.settingsDatabaseExportReady;
    final exportFailedMessage = context.lang.settingsDatabaseExportFailed;

    setState(() => _isExporting = true);
    try {
      final service = ref.read(databaseBackupServiceProvider);
      final bytes = await service.exportToBytes(_selectedScope);
      final savedPath = await FilePicker.saveFile(
        fileName: service.exportFileName(_selectedScope),
        bytes: bytes,
        type: FileType.any,
      );
      if (savedPath == null) return;

      if (!mounted) return;
      _showSnackBar(exportSavedMessage);
    } on MissingPluginException {
      final service = ref.read(databaseBackupServiceProvider);
      final file = await service.exportToFile(_selectedScope);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: exportShareText),
      );
      if (!mounted) return;
      _showSnackBar(exportReadyMessage);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(exportFailedMessage);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _pickAndImportDatabase() async {
    final importerUnavailableMessage =
        context.lang.settingsDatabaseImporterUnavailable;
    final pickJsonMessage = context.lang.settingsDatabasePickJson;
    final fileReadFailedMessage = context.lang.settingsDatabaseFileReadFailed;
    final invalidExportMessage = context.lang.settingsDatabaseInvalidExport;
    final importFailedMessage = context.lang.settingsDatabaseImportFailed;
    final importSuccessMessage = context.lang.settingsDatabaseImportSuccess;

    PlatformFile? file;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      file = result?.files.single;
    } on MissingPluginException {
      if (!mounted) return;
      _showSnackBar(importerUnavailableMessage);
      return;
    }

    if (file == null) return;
    final path = file.path;
    final fileName = file.name.toLowerCase();
    final pathName = path?.toLowerCase();
    if (!fileName.endsWith('.json') && pathName?.endsWith('.json') != true) {
      _showSnackBar(pickJsonMessage);
      return;
    }

    if (!mounted) return;
    final confirmed = await _confirmImport();
    if (confirmed != true) return;

    setState(() => _isImporting = true);
    try {
      final service = ref.read(databaseBackupServiceProvider);
      if (file.bytes == null && path == null) {
        _showSnackBar(fileReadFailedMessage);
        return;
      }

      final result = file.bytes != null
          ? await service.importFromBytes(file.bytes!)
          : await service.importFromFile(File(path!));
      if (!mounted) return;
      _showSnackBar(importSuccessMessage(result.rowCount));
    } on FormatException {
      if (!mounted) return;
      _showSnackBar(invalidExportMessage);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(importFailedMessage);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<bool?> _confirmImport() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.lang.settingsDatabaseConfirmImportTitle),
        content: Text(context.lang.settingsDatabaseConfirmImportMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.lang.settingsCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.lang.settingsImport),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearHistory() async {
    final clearSuccessMessage = context.lang.settingsDatabaseClearSuccess;
    final clearFailedMessage = context.lang.settingsDatabaseClearFailed;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.lang.settingsDatabaseConfirmClearTitle),
        content: Text(context.lang.settingsDatabaseConfirmClearMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.lang.settingsCancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.lang.settingsClear),
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
      _showSnackBar(clearSuccessMessage);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(clearFailedMessage);
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
          title: Text(context.lang.settingsDatabaseCoreScopeTitle),
          subtitle: Text(context.lang.settingsDatabaseCoreScopeSubtitle),
        ),
        CheckboxListTile(
          value: value == DatabaseBackupScope.full,
          onChanged: (_) => onChanged(DatabaseBackupScope.full),
          contentPadding: EdgeInsets.zero,
          title: Text(context.lang.settingsDatabaseFullScopeTitle),
          subtitle: Text(context.lang.settingsDatabaseFullScopeSubtitle),
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

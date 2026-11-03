import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/language.dart';
import '../profile/profile_photo_controller.dart';
import 'profile_avatar.dart';

class ProfilePhotoPicker extends ConsumerWidget {
  const ProfilePhotoPicker({super.key, this.name, this.enabled = true});

  final String? name;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(profilePhotoControllerProvider);
    final path = photo.asData?.value;

    Future<void> updatePhoto({required bool remove}) async {
      try {
        final controller = ref.read(profilePhotoControllerProvider.notifier);
        if (remove) {
          await controller.remove();
        } else {
          await controller.choose();
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.lang.settingsProfilePhotoError)),
          );
        }
      }
    }

    return PopupMenuButton<bool>(
      enabled: enabled && !photo.isLoading,
      tooltip: context.lang.settingsProfilePhotoTitle,
      onSelected: (remove) => updatePhoto(remove: remove),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: false,
          child: Text(
            path == null
                ? context.lang.settingsProfilePhotoChoose
                : context.lang.settingsProfilePhotoChange,
          ),
        ),
        if (path != null)
          PopupMenuItem(
            value: true,
            child: Text(context.lang.settingsProfilePhotoRemove),
          ),
      ],
      child: SizedBox.square(
        dimension: 56,
        child: photo.isLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  ProfileAvatar(photoPath: path, name: name, size: 48),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.photoPath, this.name, this.size = 40});

  final String? photoPath;
  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final words =
        name
            ?.trim()
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .toList() ??
        [];
    final initials = words
        .take(2)
        .map((word) => word.characters.first)
        .join()
        .toUpperCase();
    final fallback = Center(
      child: initials.isEmpty
          ? Icon(
              Icons.person_outline,
              size: size * 0.55,
              color: colors.onPrimaryContainer,
            )
          : Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.36,
                color: colors.onPrimaryContainer,
              ),
            ),
    );
    return ExcludeSemantics(
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: ColoredBox(
            color: colors.primaryContainer,
            child: photoPath == null
                ? fallback
                : Image.file(
                    File(photoPath!),
                    fit: BoxFit.cover,
                    cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                        .round(),
                    errorBuilder: (context, error, stackTrace) => fallback,
                  ),
          ),
        ),
      ),
    );
  }
}

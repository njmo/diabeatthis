import 'package:flutter/material.dart';

class FamilyAccountAvatar extends StatelessWidget {
  const FamilyAccountAvatar({super.key, this.photoUrl});
  final String? photoUrl;
  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(photoUrl ?? '');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.person_outline));
    }
    return ClipOval(
      child: Image.network(
        uri.toString(),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) =>
            const CircleAvatar(child: Icon(Icons.person_outline)),
      ),
    );
  }
}

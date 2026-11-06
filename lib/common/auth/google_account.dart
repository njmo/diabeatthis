class GoogleAccount {
  const GoogleAccount({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
  });
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  String get label => displayName?.trim().isNotEmpty == true
      ? displayName!.trim()
      : email?.trim() ?? '';
}

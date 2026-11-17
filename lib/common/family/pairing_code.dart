/// Accept the same separators and ambiguous letters as the Crockford backend.
bool isValidPairingCode(String code) {
  if (code.length > 32) return false;
  final normalized = code
      .replaceAll(RegExp(r'[-\s]'), '')
      .toUpperCase()
      .replaceAll(RegExp('[IL]'), '1')
      .replaceAll('O', '0');
  return RegExp(
    r'^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{8}$',
  ).hasMatch(normalized);
}

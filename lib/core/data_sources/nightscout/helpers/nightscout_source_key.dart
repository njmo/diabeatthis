/// Server identity without credentials, token query parameters or fragments.
String nightscoutSourceKey(String url) {
  final uri = Uri.parse(url.trim());
  if (!uri.hasAuthority || !['http', 'https'].contains(uri.scheme)) {
    throw ArgumentError('A Nightscout source must be an absolute HTTP(S) URL');
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path.replaceFirst(RegExp(r'/+$'), ''),
  ).toString();
}

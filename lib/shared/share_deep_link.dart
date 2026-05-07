/// Custom URL scheme for opening a session from a shared link (MVP).
/// Example: `dropinbad://session/<sessionPublicGuid>`
const String kSessionShareScheme = 'dropinbad';
const String kSessionShareHost = 'session';

String buildSessionShareLink(String sessionPublicId) {
  return '$kSessionShareScheme://$kSessionShareHost/$sessionPublicId';
}

/// Returns session public GUID if [uri] is a session share link, otherwise null.
String? parseSessionPublicIdFromAppLink(Uri uri) {
  if (uri.scheme != kSessionShareScheme) return null;
  if (uri.host != kSessionShareHost) return null;
  if (uri.pathSegments.isEmpty) return null;
  final id = uri.pathSegments.first;
  if (id.isEmpty) return null;
  return id;
}

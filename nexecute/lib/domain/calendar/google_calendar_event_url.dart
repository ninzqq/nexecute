Uri? safeGoogleCalendarEventUrl(Uri? uri) {
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443)) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (host != 'google.com' && !host.endsWith('.google.com')) return null;
  return uri;
}

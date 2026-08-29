class AiEndpointValidation {
  const AiEndpointValidation({this.uri, this.error, this.warning});

  final Uri? uri;
  final String? error;
  final String? warning;

  bool get isValid => error == null && uri != null;
}

AiEndpointValidation validateAiEndpointUrl(
  String value, {
  required bool isWeb,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return const AiEndpointValidation(error: 'Enter a base URL.');
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return const AiEndpointValidation(
      error: 'Enter a complete URL including http:// or https://.',
    );
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return const AiEndpointValidation(
      error: 'Only HTTP and HTTPS endpoints are supported.',
    );
  }
  if (uri.hasQuery || uri.hasFragment) {
    return const AiEndpointValidation(
      error: 'The base URL cannot contain a query or fragment.',
    );
  }
  if (uri.userInfo.isNotEmpty) {
    return const AiEndpointValidation(
      error: 'Do not put credentials in the endpoint URL.',
    );
  }

  String? warning;
  if (uri.scheme == 'http') {
    warning =
        isWeb
            ? 'Plain HTTP is normally blocked when Nexecute is served over HTTPS. Use an HTTPS endpoint.'
            : 'Plain HTTP exposes prompts on the network. Use it only on a trusted local network or tailnet.';
  }
  if (_isLoopbackHost(uri.host)) {
    final loopbackWarning =
        'localhost points to this device, not another computer on your network.';
    warning = warning == null ? loopbackWarning : '$warning $loopbackWarning';
  }

  return AiEndpointValidation(uri: uri, warning: warning);
}

bool _isLoopbackHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}

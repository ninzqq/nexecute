import 'package:nexecute/ai/domain/ai_web_search.dart';

abstract final class AiWebSearchConnectionProfileCodec {
  static const schemaVersion = 1;

  static Map<String, Object?> toMap(AiWebSearchConnectionProfile profile) => {
    'schemaVersion': schemaVersion,
    'id': profile.id,
    'name': profile.name,
    'providerKind': profile.providerKind.name,
    'baseUrl': profile.baseUrl.toString(),
    'enabled': profile.enabled,
    'credentialReference': profile.credentialReference,
    'country': profile.country,
    'searchLanguage': profile.searchLanguage,
    'safeSearch': profile.safeSearch.name,
    'requestTimeoutSeconds': profile.requestTimeout.inSeconds,
  };

  static AiWebSearchConnectionProfile fromMap(Map<String, Object?> map) {
    const fields = {
      'schemaVersion',
      'id',
      'name',
      'providerKind',
      'baseUrl',
      'enabled',
      'credentialReference',
      'country',
      'searchLanguage',
      'safeSearch',
      'requestTimeoutSeconds',
    };
    if (map.keys.toSet().difference(fields).isNotEmpty ||
        fields.difference(map.keys.toSet()).isNotEmpty ||
        map['schemaVersion'] != schemaVersion) {
      throw const FormatException('Invalid web-search connection profile.');
    }
    final profile = AiWebSearchConnectionProfile(
      id: _string(map, 'id'),
      name: _string(map, 'name'),
      providerKind: _enumValue(
        AiWebSearchProviderKind.values,
        _string(map, 'providerKind'),
        'providerKind',
      ),
      baseUrl: Uri.parse(_string(map, 'baseUrl')),
      enabled: _bool(map, 'enabled'),
      credentialReference: _nullableString(map, 'credentialReference'),
      country: _string(map, 'country'),
      searchLanguage: _string(map, 'searchLanguage'),
      safeSearch: _enumValue(
        AiWebSearchSafeSearch.values,
        _string(map, 'safeSearch'),
        'safeSearch',
      ),
      requestTimeout: Duration(seconds: _int(map, 'requestTimeoutSeconds')),
    );
    if (!profile.isValid) {
      throw const FormatException('Invalid web-search connection profile.');
    }
    return profile;
  }
}

String _string(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) throw FormatException('Invalid $key.');
  return value;
}

String? _nullableString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Invalid $key.');
}

bool _bool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! bool) throw FormatException('Invalid $key.');
  return value;
}

int _int(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! int) throw FormatException('Invalid $key.');
  return value;
}

T _enumValue<T extends Enum>(List<T> values, String name, String field) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Invalid $field.');
}

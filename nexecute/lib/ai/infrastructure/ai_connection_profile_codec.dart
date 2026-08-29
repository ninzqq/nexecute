import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_protocol.dart';

class AiConnectionProfileCodec {
  const AiConnectionProfileCodec._();

  static Map<String, Object?> toMap(AiConnectionProfile profile) {
    return {
      'id': profile.id,
      'name': profile.name,
      'protocol': profile.protocol.name,
      'baseUrl': profile.baseUrl.toString(),
      'modelId': profile.modelId,
      'authenticationMode': profile.authenticationMode.name,
      'credentialReference': profile.credentialReference,
      'reasoningEffort': profile.reasoningEffort.name,
      'maxOutputTokens': profile.maxOutputTokens,
      'connectionTimeoutSeconds': profile.connectionTimeout.inSeconds,
      'responseIdleTimeoutSeconds': profile.responseIdleTimeout.inSeconds,
      'capabilityOverrides': {
        for (final entry in profile.capabilityOverrides.entries)
          entry.key.name: entry.value,
      },
    };
  }

  static AiConnectionProfile fromMap(Map<String, Object?> map) {
    final id = _requiredString(map, 'id');
    final name = _requiredString(map, 'name');
    final protocol = _enumValue(
      AiProtocol.values,
      _requiredString(map, 'protocol'),
      'protocol',
    );
    final baseUrl = Uri.tryParse(_requiredString(map, 'baseUrl'));
    if (baseUrl == null) {
      throw const FormatException('Invalid AI connection profile baseUrl');
    }
    final modelId = _requiredString(map, 'modelId');
    final authenticationMode = _enumValue(
      AiAuthenticationMode.values,
      _requiredString(map, 'authenticationMode'),
      'authenticationMode',
    );
    final credentialReference = map['credentialReference'];
    if (credentialReference != null && credentialReference is! String) {
      throw const FormatException(
        'Invalid AI connection profile credentialReference',
      );
    }

    return AiConnectionProfile(
      id: id,
      name: name,
      protocol: protocol,
      baseUrl: baseUrl,
      modelId: modelId,
      authenticationMode: authenticationMode,
      credentialReference: credentialReference as String?,
      reasoningEffort:
          map['reasoningEffort'] == null
              ? AiReasoningEffort.automatic
              : _enumValue(
                AiReasoningEffort.values,
                _requiredString(map, 'reasoningEffort'),
                'reasoningEffort',
              ),
      maxOutputTokens: _optionalBoundedInt(
        map,
        'maxOutputTokens',
        aiDefaultMaxOutputTokens,
        minimum: aiMinOutputTokens,
        maximum: aiMaxOutputTokens,
      ),
      connectionTimeout: Duration(
        seconds: _optionalBoundedInt(
          map,
          'connectionTimeoutSeconds',
          aiDefaultConnectionTimeout.inSeconds,
          minimum: aiMinTimeoutSeconds,
          maximum: aiMaxTimeoutSeconds,
        ),
      ),
      responseIdleTimeout: Duration(
        seconds: _optionalBoundedInt(
          map,
          'responseIdleTimeoutSeconds',
          aiDefaultResponseIdleTimeout.inSeconds,
          minimum: aiMinTimeoutSeconds,
          maximum: aiMaxTimeoutSeconds,
        ),
      ),
      capabilityOverrides: _capabilityOverrides(map['capabilityOverrides']),
    );
  }

  static String _requiredString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String) {
      throw FormatException('Invalid AI connection profile $key');
    }
    return value;
  }

  static T _enumValue<T>(Iterable<T> values, String name, String field) {
    for (final value in values) {
      if ((value as Enum).name == name) return value;
    }
    throw FormatException('Unknown AI connection profile $field: $name');
  }

  static int _optionalBoundedInt(
    Map<String, Object?> map,
    String key,
    int fallback, {
    required int minimum,
    required int maximum,
  }) {
    final value = map[key];
    if (value == null) return fallback;
    if (value is! int || value < minimum || value > maximum) {
      throw FormatException('Invalid AI connection profile $key');
    }
    return value;
  }

  static Map<AiCapability, bool> _capabilityOverrides(Object? value) {
    if (value == null) return const {};
    if (value is! Map) {
      throw const FormatException(
        'Invalid AI connection profile capabilityOverrides',
      );
    }

    final overrides = <AiCapability, bool>{};
    for (final entry in value.entries) {
      if (entry.key is! String || entry.value is! bool) {
        throw const FormatException(
          'Invalid AI connection profile capability override',
        );
      }
      overrides[_enumValue(
            AiCapability.values,
            entry.key as String,
            'capability',
          )] =
          entry.value as bool;
    }
    return overrides;
  }
}

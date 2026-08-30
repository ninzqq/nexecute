import 'dart:convert';

import 'package:nexecute/ai/domain/ai_application_context.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_protocol.dart';

abstract final class AiReadToolNames {
  static const listTasks = 'listTasks';
  static const eventsForDateRange = 'eventsForDateRange';
  static const searchNotes = 'searchNotes';
  static const getNote = 'getNote';
}

sealed class AiToolParameterSchema {
  const AiToolParameterSchema();

  Map<String, Object?> toJson();
}

final class AiToolObjectSchema extends AiToolParameterSchema {
  AiToolObjectSchema({
    required Map<String, AiToolParameterSchema> properties,
    Set<String> requiredProperties = const {},
  }) : properties = Map.unmodifiable(properties),
       requiredProperties = Set.unmodifiable(requiredProperties) {
    if (!requiredProperties.every(properties.containsKey)) {
      throw ArgumentError(
        'Every required property must have a corresponding schema.',
      );
    }
  }

  final Map<String, AiToolParameterSchema> properties;
  final Set<String> requiredProperties;

  @override
  Map<String, Object?> toJson() => {
    'type': 'object',
    'properties': {
      for (final entry in properties.entries) entry.key: entry.value.toJson(),
    },
    'required': requiredProperties.toList(growable: false),
    'additionalProperties': false,
  };
}

final class AiToolStringSchema extends AiToolParameterSchema {
  AiToolStringSchema({
    this.description,
    this.minLength,
    this.maxLength,
    this.format,
    List<String> allowedValues = const [],
  }) : allowedValues = List.unmodifiable(allowedValues);

  final String? description;
  final int? minLength;
  final int? maxLength;
  final String? format;
  final List<String> allowedValues;

  @override
  Map<String, Object?> toJson() => {
    'type': 'string',
    if (description != null) 'description': description,
    if (minLength != null) 'minLength': minLength,
    if (maxLength != null) 'maxLength': maxLength,
    if (format != null) 'format': format,
    if (allowedValues.isNotEmpty) 'enum': allowedValues,
  };
}

final class AiToolIntegerSchema extends AiToolParameterSchema {
  const AiToolIntegerSchema({required this.minimum, required this.maximum});

  final int minimum;
  final int maximum;

  @override
  Map<String, Object?> toJson() => {
    'type': 'integer',
    'minimum': minimum,
    'maximum': maximum,
  };
}

class AiToolDefinition {
  AiToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  }) {
    if (parameters.requiredProperties.length != parameters.properties.length) {
      throw ArgumentError.value(
        parameters.requiredProperties,
        'parameters',
        'strict tool schemas must require every declared property',
      );
    }
  }

  final String name;
  final String description;
  final AiToolObjectSchema parameters;
}

class AiToolCall {
  AiToolCall({
    required this.id,
    required this.name,
    required Map<String, Object?> arguments,
  }) : arguments = _immutableJsonObject(arguments, 'arguments');

  final String id;
  final String name;
  final Map<String, Object?> arguments;
}

sealed class AiToolContinuationMessage {
  const AiToolContinuationMessage();
}

final class AiAssistantToolCallMessage extends AiToolContinuationMessage {
  AiAssistantToolCallMessage({required List<AiToolCall> calls, this.content})
    : calls = List.unmodifiable(calls) {
    if (calls.isEmpty) {
      throw ArgumentError.value(calls, 'calls', 'must not be empty');
    }
  }

  final String? content;
  final List<AiToolCall> calls;
}

final class AiToolResultMessage extends AiToolContinuationMessage {
  AiToolResultMessage({
    required this.toolCallId,
    required this.toolName,
    required Map<String, Object?> result,
    this.isError = false,
  }) : result = _immutableJsonObject(result, 'result');

  final String toolCallId;
  final String toolName;
  final Map<String, Object?> result;
  final bool isError;
}

class AiReadToolAuthorization {
  AiReadToolAuthorization({
    this.allowActiveTasks = false,
    this.allowNoteSearch = false,
    this.eventRange,
    Set<String> allowedNoteReferences = const {},
  }) : allowedNoteReferences = Set.unmodifiable(allowedNoteReferences) {
    if (allowedNoteReferences.length >
        AiApplicationContextLimits.maxSelectedNotes) {
      throw ArgumentError.value(
        allowedNoteReferences.length,
        'allowedNoteReferences',
        'must not contain more than '
            '${AiApplicationContextLimits.maxSelectedNotes} references',
      );
    }
    for (final reference in allowedNoteReferences) {
      if (reference.isEmpty ||
          reference.length > 128 ||
          !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(reference)) {
        throw ArgumentError.value(
          reference,
          'allowedNoteReferences',
          'contains an invalid opaque note reference',
        );
      }
    }
    final range = eventRange;
    if (range != null && !_isValidEventRange(range)) {
      throw ArgumentError.value(
        range,
        'eventRange',
        'must be a positive range of at most '
            '${AiApplicationContextLimits.maxEventRangeDays} calendar days',
      );
    }
  }

  final bool allowActiveTasks;
  final bool allowNoteSearch;
  final AiEventContextRange? eventRange;
  final Set<String> allowedNoteReferences;
}

abstract final class AiReadToolCatalog {
  static List<AiToolDefinition> definitionsFor({
    required AiConnectionProfile profile,
    AiReadToolAuthorization? authorization,
  }) {
    if (authorization == null ||
        profile.capabilityState(AiCapability.tools) !=
            AiCapabilityState.confirmedSupported) {
      return const [];
    }
    return List.unmodifiable([
      if (authorization.allowActiveTasks) _listTasks,
      if (authorization.eventRange case final range?)
        _eventsForDateRange(range),
      if (authorization.allowNoteSearch) _searchNotes,
      if (authorization.allowedNoteReferences.isNotEmpty)
        _getNote(authorization.allowedNoteReferences),
    ]);
  }

  static final AiToolDefinition _listTasks = AiToolDefinition(
    name: AiReadToolNames.listTasks,
    description: 'List the active, unfinished tasks authorized by the user.',
    parameters: AiToolObjectSchema(
      properties: const {
        'limit': AiToolIntegerSchema(
          minimum: 1,
          maximum: AiApplicationContextLimits.maxActiveTasks,
        ),
      },
      requiredProperties: const {'limit'},
    ),
  );

  static final AiToolDefinition _searchNotes = AiToolDefinition(
    name: AiReadToolNames.searchNotes,
    description: 'Search the user-authorized notes by local text matching.',
    parameters: AiToolObjectSchema(
      properties: {
        'query': AiToolStringSchema(minLength: 2, maxLength: 100),
        'limit': const AiToolIntegerSchema(
          minimum: 1,
          maximum: AiApplicationContextLimits.maxSelectedNotes,
        ),
      },
      requiredProperties: const {'query', 'limit'},
    ),
  );

  static AiToolDefinition _eventsForDateRange(AiEventContextRange range) =>
      AiToolDefinition(
        name: AiReadToolNames.eventsForDateRange,
        description:
            'List events within the user-authorized range from '
            '${range.toJson()['startInclusive']} through '
            '${range.toJson()['endExclusive']} (end exclusive).',
        parameters: AiToolObjectSchema(
          properties: {
            'startInclusive': AiToolStringSchema(format: 'date-time'),
            'endExclusive': AiToolStringSchema(format: 'date-time'),
            'limit': const AiToolIntegerSchema(
              minimum: 1,
              maximum: AiApplicationContextLimits.maxEvents,
            ),
          },
          requiredProperties: const {'startInclusive', 'endExclusive', 'limit'},
        ),
      );

  static AiToolDefinition _getNote(Set<String> references) => AiToolDefinition(
    name: AiReadToolNames.getNote,
    description:
        'Read one note previously selected or found within the '
        'user-authorized request scope.',
    parameters: AiToolObjectSchema(
      properties: {
        'noteReference': AiToolStringSchema(
          maxLength: 128,
          allowedValues: references.toList()..sort(),
        ),
      },
      requiredProperties: const {'noteReference'},
    ),
  );
}

bool _isValidEventRange(AiEventContextRange range) {
  if (!range.endExclusive.isAfter(range.startInclusive)) return false;
  final startDay = DateTime.utc(
    range.startInclusive.year,
    range.startInclusive.month,
    range.startInclusive.day,
  );
  final endDay = DateTime.utc(
    range.endExclusive.year,
    range.endExclusive.month,
    range.endExclusive.day,
  );
  return endDay.difference(startDay).inDays <=
      AiApplicationContextLimits.maxEventRangeDays;
}

Map<String, Object?> _immutableJsonObject(
  Map<String, Object?> value,
  String argumentName,
) {
  try {
    final decoded = jsonDecode(jsonEncode(value));
    if (decoded is! Map<String, dynamic>) throw const FormatException();
    return Map.unmodifiable({
      for (final entry in decoded.entries)
        entry.key: _immutableJsonValue(entry.value),
    });
  } catch (_) {
    throw ArgumentError.value(
      value,
      argumentName,
      'must contain only JSON-compatible values',
    );
  }
}

Object? _immutableJsonValue(Object? value) => switch (value) {
  Map<String, dynamic>() => Map.unmodifiable({
    for (final entry in value.entries)
      entry.key: _immutableJsonValue(entry.value),
  }),
  List<dynamic>() => List.unmodifiable(value.map(_immutableJsonValue)),
  _ => value,
};

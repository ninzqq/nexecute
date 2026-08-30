import 'dart:convert';

import 'package:nexecute/ai/domain/ai_event_proposal.dart';

abstract final class AiEventProposalParser {
  static const _eventKeys = {
    'title',
    'description',
    'startDate',
    'startTime',
    'endDate',
    'endTime',
    'isAllDay',
  };

  static final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _timePattern = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');

  static AiEventProposal parse(String response) {
    if (response.length > aiMaxEventProposalResponseCharacters) {
      throw const AiEventProposalFormatException(
        AiEventProposalErrorCode.responseTooLarge,
        'The model response was too large to be an event proposal.',
      );
    }

    final jsonText = _unwrapJsonFence(response.trim());
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      throw const AiEventProposalFormatException(
        AiEventProposalErrorCode.invalidJson,
        'The model did not return valid JSON.',
      );
    }

    final root = _stringMap(decoded, 'The proposal must be a JSON object.');
    if (!_hasExactKeys(root, const {'schemaVersion', 'event'})) {
      throw const AiEventProposalFormatException(
        AiEventProposalErrorCode.invalidShape,
        'The proposal contains missing or unsupported fields.',
      );
    }

    final version = root['schemaVersion'];
    if (version is! int || version != aiEventProposalSchemaVersion) {
      throw const AiEventProposalFormatException(
        AiEventProposalErrorCode.unsupportedVersion,
        'The event-proposal version is not supported.',
      );
    }

    final rawEvent = root['event'];
    if (rawEvent == null) {
      return AiEventProposal(schemaVersion: version, event: null);
    }
    final event = _parseEvent(rawEvent);
    return AiEventProposal(schemaVersion: version, event: event);
  }

  static AiProposedEvent _parseEvent(Object? value) {
    final event = _stringMap(value, 'The proposed event must be an object.');
    if (!_hasExactKeys(event, _eventKeys)) {
      throw const AiEventProposalFormatException(
        AiEventProposalErrorCode.invalidEvent,
        'The proposed event contains missing or unsupported fields.',
      );
    }

    final title = _requiredTitle(event['title']);
    final description = _description(event['description']);
    final startDate = _optionalDate(event['startDate'], 'startDate');
    final startTime = _optionalTime(event['startTime'], 'startTime');
    final endDate = _optionalDate(event['endDate'], 'endDate');
    final endTime = _optionalTime(event['endTime'], 'endTime');
    final rawIsAllDay = event['isAllDay'];
    if (rawIsAllDay != null && rawIsAllDay is! bool) {
      throw const AiEventProposalFormatException(
        AiEventProposalErrorCode.invalidEvent,
        'The all-day value must be true, false, or null.',
      );
    }
    final isAllDay = rawIsAllDay as bool?;

    if (isAllDay == true && (startTime != null || endTime != null)) {
      throw const AiEventProposalFormatException(
        AiEventProposalErrorCode.invalidTime,
        'An all-day proposal cannot contain wall-clock times.',
      );
    }
    _validateRange(
      startDate: startDate,
      startTime: startTime,
      endDate: endDate,
      endTime: endTime,
      isAllDay: isAllDay,
    );

    return AiProposedEvent(
      title: title,
      description: description,
      startDate: startDate,
      startTime: startTime,
      endDate: endDate,
      endTime: endTime,
      isAllDay: isAllDay,
    );
  }

  static String _requiredTitle(Object? value) {
    if (value is! String) {
      throw const AiEventProposalFormatException(
        AiEventProposalErrorCode.invalidTitle,
        'The proposed event must have a text title.',
      );
    }
    final title = value.trim();
    if (title.isEmpty ||
        title.length > aiMaxProposedEventTitleCharacters ||
        title.contains('\n') ||
        title.contains('\r')) {
      throw const AiEventProposalFormatException(
        AiEventProposalErrorCode.invalidTitle,
        'The event title must be one non-empty line of at most 200 characters.',
      );
    }
    return title;
  }

  static String _description(Object? value) {
    if (value is! String) {
      throw const AiEventProposalFormatException(
        AiEventProposalErrorCode.invalidDescription,
        'The proposed event description must be text.',
      );
    }
    final description = value.trim();
    if (description.length > aiMaxProposedEventDescriptionCharacters) {
      throw const AiEventProposalFormatException(
        AiEventProposalErrorCode.invalidDescription,
        'The event description is too long.',
      );
    }
    return description;
  }

  static String? _optionalDate(Object? value, String field) {
    if (value == null) return null;
    if (value is! String || !_datePattern.hasMatch(value)) {
      throw AiEventProposalFormatException(
        AiEventProposalErrorCode.invalidDate,
        '$field must use YYYY-MM-DD or be null.',
      );
    }
    final parts = value.split('-').map(int.parse).toList();
    final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
    if (parsed.year != parts[0] ||
        parsed.month != parts[1] ||
        parsed.day != parts[2]) {
      throw AiEventProposalFormatException(
        AiEventProposalErrorCode.invalidDate,
        '$field is not a real calendar date.',
      );
    }
    return value;
  }

  static String? _optionalTime(Object? value, String field) {
    if (value == null) return null;
    if (value is! String || !_timePattern.hasMatch(value)) {
      throw AiEventProposalFormatException(
        AiEventProposalErrorCode.invalidTime,
        '$field must use 24-hour HH:mm or be null.',
      );
    }
    return value;
  }

  static void _validateRange({
    required String? startDate,
    required String? startTime,
    required String? endDate,
    required String? endTime,
    required bool? isAllDay,
  }) {
    if (startDate == null || endDate == null) return;
    final startDay = _dateTime(startDate);
    final endDay = _dateTime(endDate);
    if (endDay.isBefore(startDay)) {
      throw const AiEventProposalFormatException(
        AiEventProposalErrorCode.invalidRange,
        'The event cannot end before it starts.',
      );
    }
    if (endDay.difference(startDay).inDays >= aiMaxProposedEventSpanDays) {
      throw const AiEventProposalFormatException(
        AiEventProposalErrorCode.invalidRange,
        'The proposed event spans too many days.',
      );
    }

    if (isAllDay == true || startTime == null || endTime == null) return;
    final start = _dateTime(startDate, startTime);
    final end = _dateTime(endDate, endTime);
    if (!end.isAfter(start)) {
      throw const AiEventProposalFormatException(
        AiEventProposalErrorCode.invalidRange,
        'A timed event must end after it starts.',
      );
    }
  }

  static DateTime _dateTime(String date, [String? time]) {
    final dateParts = date.split('-').map(int.parse).toList();
    final timeParts = time?.split(':').map(int.parse).toList();
    return DateTime.utc(
      dateParts[0],
      dateParts[1],
      dateParts[2],
      timeParts?[0] ?? 0,
      timeParts?[1] ?? 0,
    );
  }

  static Map<String, Object?> _stringMap(Object? value, String message) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw AiEventProposalFormatException(
        AiEventProposalErrorCode.invalidShape,
        message,
      );
    }
    return Map<String, Object?>.from(value);
  }

  static bool _hasExactKeys(Map<String, Object?> value, Set<String> expected) {
    return value.length == expected.length &&
        value.keys.every(expected.contains);
  }

  static String _unwrapJsonFence(String response) {
    final match = RegExp(
      r'^```(?:json)?\s*(.*?)\s*```$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(response);
    return match?.group(1)?.trim() ?? response;
  }
}

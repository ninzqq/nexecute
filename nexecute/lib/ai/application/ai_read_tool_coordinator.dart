import 'dart:async';
import 'dart:convert';

import 'package:nexecute/ai/application/ai_application_context_read_service.dart';
import 'package:nexecute/ai/domain/ai_application_context.dart';
import 'package:nexecute/ai/domain/ai_chat_request.dart';
import 'package:nexecute/ai/domain/ai_stream_event.dart';
import 'package:nexecute/ai/domain/ai_tool.dart';
import 'package:nexecute/ai/repositories/ai_assistant_repository.dart';
import 'package:nexecute/ai/repositories/ai_response_handle.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:uuid/uuid.dart';

abstract final class AiReadToolExecutionLimits {
  static const maxCallsPerRound = 4;
  static const maxTotalCalls = 8;
  static const maxContinuationRounds = 3;
  static const maxCumulativeResultCharacters = 48000;
  static const maxToolNameCharacters = 64;
  static const maxArgumentCharacters = 4000;
  static const executionTimeout = Duration(seconds: 30);
}

class AiReadToolExecutionScope {
  AiReadToolExecutionScope({
    required this.authorization,
    Map<String, String> noteIdsByReference = const {},
  }) : noteIdsByReference = Map.unmodifiable(noteIdsByReference) {
    if (noteIdsByReference.keys.toSet().length != noteIdsByReference.length ||
        noteIdsByReference.values.toSet().length != noteIdsByReference.length ||
        !authorization.allowedNoteReferences.containsAll(
          noteIdsByReference.keys,
        ) ||
        !noteIdsByReference.keys.toSet().containsAll(
          authorization.allowedNoteReferences,
        )) {
      throw ArgumentError.value(
        noteIdsByReference,
        'noteIdsByReference',
        'must map every authorized opaque reference to one unique note ID',
      );
    }
    _applicationScope(
      authorization: authorization,
      noteIds: noteIdsByReference.values.toSet(),
    );
  }

  final AiReadToolAuthorization authorization;
  final Map<String, String> noteIdsByReference;
}

class AiReadToolCoordinator {
  AiReadToolCoordinator({
    required AiAssistantRepository assistantRepository,
    required AiApplicationContextReadService readService,
    String Function()? opaqueReferenceFactory,
    this.executionTimeout = AiReadToolExecutionLimits.executionTimeout,
  }) : _assistantRepository = assistantRepository,
       _readService = readService,
       _opaqueReferenceFactory =
           opaqueReferenceFactory ?? (() => 'note_${const Uuid().v4()}') {
    if (executionTimeout <= Duration.zero) {
      throw ArgumentError.value(
        executionTimeout,
        'executionTimeout',
        'must be greater than zero',
      );
    }
  }

  final AiAssistantRepository _assistantRepository;
  final AiApplicationContextReadService _readService;
  final String Function() _opaqueReferenceFactory;
  final Duration executionTimeout;

  Future<AiResponseHandle> startResponse(
    AiChatRequest request, {
    required AiReadToolExecutionScope scope,
  }) async {
    final definitions = AiReadToolCatalog.definitionsFor(
      profile: request.connectionProfile,
      authorization: scope.authorization,
    );
    if (definitions.isEmpty) {
      return _assistantRepository.startResponse(_withoutTools(request));
    }
    final session = _AiReadToolSession(
      assistantRepository: _assistantRepository,
      readService: _readService,
      request: request,
      scope: scope,
      opaqueReferenceFactory: _opaqueReferenceFactory,
      executionTimeout: executionTimeout,
    );
    return StreamAiResponseHandle(
      events: session.run(),
      onCancel: session.cancel,
    );
  }
}

class _AiReadToolSession {
  _AiReadToolSession({
    required this.assistantRepository,
    required this.readService,
    required this.request,
    required this.scope,
    required this.opaqueReferenceFactory,
    required this.executionTimeout,
  }) : noteIdsByReference = Map.of(scope.noteIdsByReference),
       continuationMessages = List.of(request.continuationMessages);

  final AiAssistantRepository assistantRepository;
  final AiApplicationContextReadService readService;
  final AiChatRequest request;
  final AiReadToolExecutionScope scope;
  final String Function() opaqueReferenceFactory;
  final Duration executionTimeout;
  final Map<String, String> noteIdsByReference;
  final List<AiToolContinuationMessage> continuationMessages;

  AiResponseHandle? _activeHandle;
  bool _cancelled = false;
  int _totalCalls = 0;
  int _continuationRounds = 0;
  int _resultCharacters = 0;

  Future<void> cancel() async {
    _cancelled = true;
    await _activeHandle?.cancel();
  }

  Stream<AiStreamEvent> run() async* {
    while (!_cancelled) {
      final roundRequest = _requestForCurrentScope();
      AiResponseHandle handle;
      try {
        handle = await assistantRepository.startResponse(roundRequest);
      } catch (_) {
        yield _failure(
          'Could not start the AI tool continuation.',
          'tool_continuation_start_failed',
          retryable: true,
        );
        return;
      }
      if (_cancelled) {
        await handle.cancel();
        return;
      }
      _activeHandle = handle;
      final calls = <AiToolCall>[];
      final roundText = StringBuffer();
      AiResponseCompleted? completion;
      try {
        await for (final event in handle.events) {
          if (_cancelled) return;
          switch (event) {
            case AiToolCallRequested(:final call):
              calls.add(call);
            case AiTextDelta(:final text):
              roundText.write(text);
              yield event;
            case AiReasoningDelta():
              yield event;
            case AiResponseCompleted():
              completion = event;
            case AiResponseFailed():
              yield event;
              return;
          }
        }
      } catch (_) {
        yield _failure(
          'The AI tool continuation was interrupted.',
          'tool_continuation_interrupted',
          retryable: true,
        );
        return;
      } finally {
        _activeHandle = null;
      }
      if (_cancelled) return;
      if (calls.isEmpty) {
        if (completion case final value?) {
          yield value;
        } else {
          yield _failure(
            'The AI response ended before completing.',
            'tool_continuation_incomplete',
            retryable: true,
          );
        }
        return;
      }
      final boundsFailure = _validateRoundBounds(calls);
      if (boundsFailure != null) {
        yield boundsFailure;
        return;
      }

      continuationMessages.add(
        AiAssistantToolCallMessage(
          calls: calls,
          content: roundText.isEmpty ? null : roundText.toString(),
        ),
      );
      for (final call in calls) {
        if (_cancelled) return;
        final result = await _execute(call);
        if (_cancelled) return;
        final serializedLength =
            jsonEncode({
              'ok': !result.isError,
              if (result.isError)
                'error': result.result
              else
                'result': result.result,
            }).length;
        if (_resultCharacters + serializedLength >
            AiReadToolExecutionLimits.maxCumulativeResultCharacters) {
          yield _failure(
            'The cumulative tool result limit was exceeded.',
            'tool_result_limit',
          );
          return;
        }
        _resultCharacters += serializedLength;
        continuationMessages.add(result);
      }
      _continuationRounds++;
    }
  }

  AiResponseFailed? _validateRoundBounds(List<AiToolCall> calls) {
    if (_continuationRounds >=
        AiReadToolExecutionLimits.maxContinuationRounds) {
      return _failure(
        'The tool continuation round limit was exceeded.',
        'tool_round_limit',
      );
    }
    if (calls.length > AiReadToolExecutionLimits.maxCallsPerRound ||
        _totalCalls + calls.length > AiReadToolExecutionLimits.maxTotalCalls) {
      return _failure('The tool call limit was exceeded.', 'tool_call_limit');
    }
    final ids = calls.map((call) => call.id).toSet();
    if (ids.length != calls.length ||
        calls.any(
          (call) =>
              call.id.isEmpty ||
              call.id.length > 128 ||
              call.name.isEmpty ||
              call.name.length >
                  AiReadToolExecutionLimits.maxToolNameCharacters ||
              jsonEncode(call.arguments).length >
                  AiReadToolExecutionLimits.maxArgumentCharacters,
        )) {
      return _failure(
        'The endpoint returned invalid or excessive tool call data.',
        'invalid_tool_call',
      );
    }
    _totalCalls += calls.length;
    return null;
  }

  Future<AiToolResultMessage> _execute(AiToolCall call) async {
    try {
      final result = await _executeValidated(call).timeout(executionTimeout);
      return AiToolResultMessage(
        toolCallId: call.id,
        toolName: call.name,
        result: result,
      );
    } on _ToolCallRejection catch (error) {
      return _errorResult(call, error.code, error.message);
    } on AiApplicationContextReadException catch (error) {
      return _errorResult(call, error.code.name, error.message);
    } on TimeoutException {
      return _errorResult(
        call,
        'timeout',
        'The authorized application read timed out.',
      );
    } catch (_) {
      return _errorResult(
        call,
        'unavailable',
        'The authorized application read could not be completed.',
      );
    }
  }

  Future<Map<String, Object?>> _executeValidated(AiToolCall call) async {
    final authorization = _currentAuthorization();
    final applicationScope = _applicationScope(
      authorization: authorization,
      noteIds: noteIdsByReference.values.toSet(),
    );
    switch (call.name) {
      case AiReadToolNames.listTasks:
        if (!authorization.allowActiveTasks) {
          throw const _ToolCallRejection(
            'unauthorized',
            'Active-task access was not authorized for this request.',
          );
        }
        _requireExactArguments(call, const {'limit'});
        final context = await readService.listTasks(
          scope: applicationScope,
          limit: _integerArgument(
            call,
            'limit',
            maximum: AiApplicationContextLimits.maxActiveTasks,
          ),
        );
        return _contextResult(context);
      case AiReadToolNames.eventsForDateRange:
        if (authorization.eventRange == null) {
          throw const _ToolCallRejection(
            'unauthorized',
            'Event access was not authorized for this request.',
          );
        }
        _requireExactArguments(call, const {
          'startInclusive',
          'endExclusive',
          'limit',
        });
        final start = _dateTimeArgument(call, 'startInclusive');
        final end = _dateTimeArgument(call, 'endExclusive');
        if (!end.isAfter(start)) {
          throw const _ToolCallRejection(
            'invalid_arguments',
            'The event range must end after it starts.',
          );
        }
        final range = CalendarQueryRange(
          startInclusive: start,
          endExclusive: end,
        );
        final context = await readService.eventsForDateRange(
          scope: applicationScope,
          range: range,
          limit: _integerArgument(
            call,
            'limit',
            maximum: AiApplicationContextLimits.maxEvents,
          ),
        );
        return _contextResult(context);
      case AiReadToolNames.searchNotes:
        if (!authorization.allowNoteSearch) {
          throw const _ToolCallRejection(
            'unauthorized',
            'Note search was not authorized for this request.',
          );
        }
        _requireExactArguments(call, const {'query', 'limit'});
        final query = _stringArgument(
          call,
          'query',
          minimumLength:
              AiApplicationContextReadLimits.minSearchQueryCharacters,
          maximumLength:
              AiApplicationContextReadLimits.maxSearchQueryCharacters,
        );
        final result = await readService.searchNotes(
          scope: applicationScope,
          query: query,
          limit: _integerArgument(
            call,
            'limit',
            maximum: AiApplicationContextReadLimits.maxSearchResults,
          ),
        );
        final references = <String>[];
        for (final noteId in result.sourceNoteIds) {
          if (!_isUsableNoteId(noteId)) continue;
          final existing = _referenceForNoteId(noteId);
          if (existing == null &&
              noteIdsByReference.length >=
                  AiApplicationContextLimits.maxSelectedNotes) {
            continue;
          }
          final reference = existing ?? _newOpaqueReference();
          noteIdsByReference[reference] = noteId;
          references.add(reference);
        }
        return {
          'dataClassification': aiApplicationContextDataClassification,
          'context': result.context.toJson(),
          'noteReferences': references,
        };
      case AiReadToolNames.getNote:
        _requireExactArguments(call, const {'noteReference'});
        final reference = _stringArgument(
          call,
          'noteReference',
          minimumLength: 1,
          maximumLength: 128,
        );
        final noteId = noteIdsByReference[reference];
        if (noteId == null ||
            !authorization.allowedNoteReferences.contains(reference)) {
          throw const _ToolCallRejection(
            'unauthorized',
            'This note reference was not authorized for the request.',
          );
        }
        final context = await readService.getNote(
          scope: applicationScope,
          noteId: noteId,
        );
        return _contextResult(context);
      default:
        throw const _ToolCallRejection(
          'unknown_tool',
          'The requested tool is not supported.',
        );
    }
  }

  AiReadToolAuthorization _currentAuthorization() => AiReadToolAuthorization(
    allowActiveTasks: scope.authorization.allowActiveTasks,
    allowNoteSearch: scope.authorization.allowNoteSearch,
    eventRange: scope.authorization.eventRange,
    allowedNoteReferences: noteIdsByReference.keys.toSet(),
  );

  AiChatRequest _requestForCurrentScope() => AiChatRequest(
    connectionProfile: request.connectionProfile,
    conversationId: request.conversationId,
    messages: request.messages,
    systemInstruction: request.systemInstruction,
    applicationContext: request.applicationContext,
    readToolAuthorization: _currentAuthorization(),
    continuationMessages: continuationMessages,
  );

  String? _referenceForNoteId(String noteId) {
    for (final entry in noteIdsByReference.entries) {
      if (entry.value == noteId) return entry.key;
    }
    return null;
  }

  bool _isUsableNoteId(String noteId) {
    try {
      AiApplicationReadScope(allowedNoteIds: {noteId});
      return true;
    } catch (_) {
      return false;
    }
  }

  String _newOpaqueReference() {
    for (var attempt = 0; attempt < 8; attempt++) {
      final candidate = opaqueReferenceFactory();
      if (candidate.isNotEmpty &&
          candidate.length <= 128 &&
          RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(candidate) &&
          !noteIdsByReference.containsKey(candidate)) {
        return candidate;
      }
    }
    throw const _ToolCallRejection(
      'unavailable',
      'A safe note reference could not be created.',
    );
  }
}

AiApplicationReadScope _applicationScope({
  required AiReadToolAuthorization authorization,
  required Set<String> noteIds,
}) {
  final eventRange = authorization.eventRange;
  return AiApplicationReadScope(
    allowActiveTasks: authorization.allowActiveTasks,
    allowNoteSearch: authorization.allowNoteSearch,
    eventRange:
        eventRange == null
            ? null
            : CalendarQueryRange(
              startInclusive: eventRange.startInclusive,
              endExclusive: eventRange.endExclusive,
            ),
    allowedNoteIds: noteIds,
  );
}

AiChatRequest _withoutTools(AiChatRequest request) => AiChatRequest(
  connectionProfile: request.connectionProfile,
  conversationId: request.conversationId,
  messages: request.messages,
  systemInstruction: request.systemInstruction,
  applicationContext: request.applicationContext,
  continuationMessages: request.continuationMessages,
);

void _requireExactArguments(AiToolCall call, Set<String> expected) {
  final actual = call.arguments.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw const _ToolCallRejection(
      'invalid_arguments',
      'The tool arguments do not match the required schema.',
    );
  }
}

int _integerArgument(AiToolCall call, String name, {required int maximum}) {
  final value = call.arguments[name];
  if (value is! num ||
      !value.isFinite ||
      value != value.toInt() ||
      value < 1 ||
      value > maximum) {
    throw const _ToolCallRejection(
      'invalid_arguments',
      'A tool integer argument is outside its allowed range.',
    );
  }
  return value.toInt();
}

String _stringArgument(
  AiToolCall call,
  String name, {
  required int minimumLength,
  required int maximumLength,
}) {
  final value = call.arguments[name];
  if (value is! String ||
      value.length < minimumLength ||
      value.length > maximumLength) {
    throw const _ToolCallRejection(
      'invalid_arguments',
      'A tool string argument has an unsupported length.',
    );
  }
  return value;
}

DateTime _dateTimeArgument(AiToolCall call, String name) {
  final value = _stringArgument(
    call,
    name,
    minimumLength: 20,
    maximumLength: 40,
  );
  if (!RegExp(r'T.*(?:Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
    throw const _ToolCallRejection(
      'invalid_arguments',
      'Event dates must be RFC 3339 date-time values with a time zone.',
    );
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw const _ToolCallRejection(
      'invalid_arguments',
      'An event date could not be parsed.',
    );
  }
  return parsed;
}

AiToolResultMessage _errorResult(
  AiToolCall call,
  String code,
  String message,
) => AiToolResultMessage(
  toolCallId: call.id,
  toolName: call.name,
  isError: true,
  result: {'code': code, 'message': message},
);

Map<String, Object?> _contextResult(AiApplicationContextEnvelope context) => {
  'dataClassification': aiApplicationContextDataClassification,
  'context': context.toJson(),
};

AiResponseFailed _failure(
  String message,
  String code, {
  bool retryable = false,
}) => AiResponseFailed(
  error: StateError(message),
  message: message,
  code: code,
  retryable: retryable,
);

class _ToolCallRejection implements Exception {
  const _ToolCallRejection(this.code, this.message);

  final String code;
  final String message;
}

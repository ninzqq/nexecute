import 'package:flutter/material.dart';
import 'package:nexecute/ai/application/ai_conversation_note_source.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/shared/adaptive_navigation_shell.dart';
import 'package:nexecute/shared/bottom_sheet_safe_area.dart';

Future<void> showAiConversationNoteSourcePreview(
  BuildContext context, {
  required AiConversationNoteSource source,
  required AiConnectionProfile profile,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  constraints: adaptiveSheetConstraints(context),
  builder:
      (_) => BottomSheetSafeArea(
        child: _AiConversationNoteSourceSheet(source: source, profile: profile),
      ),
);

class _AiConversationNoteSourceSheet extends StatefulWidget {
  const _AiConversationNoteSourceSheet({
    required this.source,
    required this.profile,
  });

  final AiConversationNoteSource source;
  final AiConnectionProfile profile;

  @override
  State<_AiConversationNoteSourceSheet> createState() =>
      _AiConversationNoteSourceSheetState();
}

class _AiConversationNoteSourceSheetState
    extends State<_AiConversationNoteSourceSheet> {
  late AiConversationNoteSource _source = widget.source;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    String formatTime(DateTime value) {
      final local = value.toLocal();
      return '${localizations.formatMediumDate(local)} '
          '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
    }

    final payload = _source.payload;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: ListView(
          children: [
            Text(
              'Create note from conversation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Source preview · ${widget.profile.name} · '
              '${widget.profile.modelId}',
              key: const Key('conversation-note-connection'),
            ),
            const SizedBox(height: 8),
            Text(
              '${_source.selectedCount} messages selected · '
              '${_source.olderOmittedCount} older messages omitted',
              key: const Key('conversation-note-counts'),
            ),
            if (_source.startIndex > 0 || _source.newerOmittedCount > 0)
              Text(
                '${_source.startIndex} more before selection · '
                '${_source.newerOmittedCount} after selection',
                key: const Key('conversation-note-selection-omissions'),
              ),
            Text(
              '${formatTime(_source.firstMessageAt)} – '
              '${formatTime(_source.lastMessageAt)}',
              key: const Key('conversation-note-time-range'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const Key('conversation-note-start'),
                    initialValue: _source.startIndex,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Start at'),
                    items: [
                      for (final index in _source.startOptions)
                        DropdownMenuItem(
                          value: index,
                          child: Text(
                            'Message ${index + 1} · '
                            '${formatTime(_source.availableMessages[index].createdAt)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (index) {
                      if (index == null) return;
                      setState(() {
                        _source = _source.selectRange(
                          startIndex: index,
                          endIndex: _source.endIndex,
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const Key('conversation-note-end'),
                    initialValue: _source.endIndex,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Through'),
                    items: [
                      for (final index in _source.endOptions)
                        DropdownMenuItem(
                          value: index,
                          child: Text(
                            'Message ${index + 1} · '
                            '${formatTime(_source.availableMessages[index].createdAt)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (index) {
                      if (index == null) return;
                      setState(() {
                        _source = _source.selectRange(
                          startIndex: _source.startIndex,
                          endIndex: index,
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_source.isWithinLimit)
              Text(
                'This source is ${payload.length} characters; the limit is '
                '$aiMaxConversationNoteSourceCharacters. Select fewer turns '
                'before generating a note.',
                key: const Key('conversation-note-over-limit'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            const Text(
              'Only the text shown below would be sent. Earlier messages, '
              'temporary attachments, tool results, and reasoning are not '
              'included. Nothing is sent or saved from this preview.',
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    payload,
                    key: const Key('conversation-note-payload'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('conversation-note-close'),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

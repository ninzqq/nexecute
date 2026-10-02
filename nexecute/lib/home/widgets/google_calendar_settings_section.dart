import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nexecute/repositories/google_calendar_source.dart';
import 'package:nexecute/services/google_calendar_api.dart';
import 'package:nexecute/services/google_calendar_authorization.dart';

class GoogleCalendarSettingsSection extends StatefulWidget {
  const GoogleCalendarSettingsSection({
    super.key,
    this.authorization,
    this.source,
  });

  final GoogleCalendarAuthorizationService? authorization;
  final GoogleCalendarSource? source;

  @override
  State<GoogleCalendarSettingsSection> createState() =>
      _GoogleCalendarSettingsSectionState();
}

class _GoogleCalendarSettingsSectionState
    extends State<GoogleCalendarSettingsSection> {
  StreamSubscription<GoogleCalendarAuthorizationState>? _authSubscription;
  StreamSubscription<GoogleCalendarCatalogState>? _catalogSubscription;
  GoogleCalendarAuthorizationState _authState =
      GoogleCalendarAuthorizationState.disconnected;
  GoogleCalendarCatalogState _catalogState =
      GoogleCalendarCatalogState.unauthenticated();
  bool _actionPending = false;
  String? _actionMessage;

  bool get _available => widget.authorization != null && widget.source != null;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(GoogleCalendarSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authorization != widget.authorization ||
        oldWidget.source != widget.source) {
      unawaited(_unsubscribe());
      _subscribe();
    }
  }

  void _subscribe() {
    final authorization = widget.authorization;
    final source = widget.source;
    _authState =
        authorization?.state ?? GoogleCalendarAuthorizationState.disconnected;
    _catalogState =
        source?.catalogState ?? GoogleCalendarCatalogState.unauthenticated();
    _authSubscription = authorization?.states.listen(
      (state) {
        if (mounted) setState(() => _authState = state);
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _authState = const GoogleCalendarAuthorizationState(
              status: GoogleCalendarAuthorizationStatus.failed,
            );
          });
        }
      },
    );
    _catalogSubscription = source?.catalogStates.listen(
      (state) {
        if (mounted) setState(() => _catalogState = state);
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _catalogState = GoogleCalendarCatalogState(
              calendars: const [],
              selectedCalendarIds: const {},
              loadState: GoogleCalendarCatalogLoadState.failed,
            );
          });
        }
      },
    );
  }

  Future<void> _unsubscribe() async {
    final authSubscription = _authSubscription;
    final catalogSubscription = _catalogSubscription;
    _authSubscription = null;
    _catalogSubscription = null;
    await Future.wait([
      if (authSubscription != null) authSubscription.cancel(),
      if (catalogSubscription != null) catalogSubscription.cancel(),
    ]);
  }

  @override
  void dispose() {
    unawaited(_unsubscribe());
    super.dispose();
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_actionPending) return;
    setState(() {
      _actionPending = true;
      _actionMessage = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() {
          _actionMessage = 'Google Calendar could not complete that action.';
        });
      }
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _confirmDisconnect() async {
    if (_actionPending) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Disconnect Google Calendar?'),
            content: const Text(
              'Google calendars will stop appearing and their local cache will be removed. You will remain signed in to Nexecute and can reconnect later.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('google-calendar-confirm-disconnect'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Disconnect'),
              ),
            ],
          ),
    );
    if (confirmed == true && mounted) {
      await _runAction(widget.authorization!.disconnect);
    }
  }

  Future<void> _manageCalendars() async {
    if (_actionPending ||
        _catalogState.loadState != GoogleCalendarCatalogLoadState.ready) {
      return;
    }
    final selection = await showDialog<Set<String>>(
      context: context,
      builder:
          (context) => _CalendarSelectionDialog(
            calendars: _catalogState.calendars,
            selectedIds: _catalogState.selectedCalendarIds,
          ),
    );
    if (selection != null && mounted) {
      await _runAction(() => widget.source!.setSelectedCalendarIds(selection));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected =
        _authState.status == GoogleCalendarAuthorizationStatus.connected;
    final canDisconnect =
        connected ||
        widget.authorization?.cacheOwner != null ||
        _authState.account != null;
    final busy =
        _actionPending ||
        _authState.status == GoogleCalendarAuthorizationStatus.checking ||
        _authState.status == GoogleCalendarAuthorizationStatus.authorizing;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Google Calendar', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (busy) ...[
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(_statusText(), style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
          if (_actionMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              _actionMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (_available) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!connected &&
                    _authState.status !=
                        GoogleCalendarAuthorizationStatus.unsupported)
                  FilledButton.icon(
                    key: const Key('google-calendar-connect'),
                    onPressed:
                        busy
                            ? null
                            : () => _runAction(widget.authorization!.connect),
                    icon: const Icon(Icons.link_rounded),
                    label: Text(_retryApplicable ? 'Retry' : 'Connect'),
                  ),
                if (connected) ...[
                  FilledButton.tonalIcon(
                    key: const Key('google-calendar-manage'),
                    onPressed:
                        busy ||
                                _catalogState.loadState !=
                                    GoogleCalendarCatalogLoadState.ready
                            ? null
                            : _manageCalendars,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Manage calendars'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('google-calendar-refresh'),
                    onPressed:
                        busy
                            ? null
                            : () => _runAction(widget.source!.refreshCalendars),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh'),
                  ),
                  TextButton.icon(
                    key: const Key('google-calendar-disconnect'),
                    onPressed: busy ? null : _confirmDisconnect,
                    icon: const Icon(Icons.link_off_rounded),
                    label: const Text('Disconnect'),
                  ),
                ] else if (canDisconnect)
                  TextButton.icon(
                    key: const Key('google-calendar-disconnect'),
                    onPressed: busy ? null : _confirmDisconnect,
                    icon: const Icon(Icons.link_off_rounded),
                    label: const Text('Disconnect'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool get _retryApplicable =>
      _authState.status == GoogleCalendarAuthorizationStatus.expired ||
      _authState.status == GoogleCalendarAuthorizationStatus.denied ||
      _authState.status == GoogleCalendarAuthorizationStatus.failed;

  String _statusText() {
    if (!_available) return 'Google Calendar is unavailable on this device.';
    final email = _authState.account?.email;
    switch (_authState.status) {
      case GoogleCalendarAuthorizationStatus.disconnected:
        return 'Not connected.';
      case GoogleCalendarAuthorizationStatus.checking:
        return 'Checking your Google Calendar connection...';
      case GoogleCalendarAuthorizationStatus.authorizing:
        return 'Waiting for Google Calendar access...';
      case GoogleCalendarAuthorizationStatus.connected:
        final catalogDetail = _catalogStatusText();
        return email == null || email.isEmpty
            ? 'Connected.$catalogDetail'
            : 'Connected as $email.$catalogDetail';
      case GoogleCalendarAuthorizationStatus.expired:
        return 'Your Google Calendar connection expired. Connect again.';
      case GoogleCalendarAuthorizationStatus.denied:
        return _authorizationIssueText(_authState.issue);
      case GoogleCalendarAuthorizationStatus.unsupported:
        return 'Google Calendar is not supported on this device.';
      case GoogleCalendarAuthorizationStatus.failed:
        return _authorizationIssueText(_authState.issue);
    }
  }

  String _catalogStatusText() {
    switch (_catalogState.loadState) {
      case GoogleCalendarCatalogLoadState.loading:
        return ' Loading calendars...';
      case GoogleCalendarCatalogLoadState.ready:
        final count = _catalogState.selectedCalendarIds.length;
        return ' $count ${count == 1 ? 'calendar' : 'calendars'} selected.';
      case GoogleCalendarCatalogLoadState.unauthenticated:
        return '';
      case GoogleCalendarCatalogLoadState.failed:
        switch (_catalogState.failure?.kind) {
          case GoogleCalendarSourceFailureKind.authorization:
            return ' Calendar access needs to be renewed.';
          case GoogleCalendarSourceFailureKind.localStore:
            return ' Saved calendar settings are unavailable.';
          case GoogleCalendarSourceFailureKind.rateLimited:
            return _catalogState.calendars.isEmpty
                ? ' Google Calendar is temporarily rate limited.'
                : ' Google Calendar is temporarily rate limited. Saved calendars remain available.';
          case GoogleCalendarSourceFailureKind.network:
            return _catalogState.calendars.isEmpty
                ? ' No network connection.'
                : ' No network connection. Saved calendars remain available.';
          case GoogleCalendarSourceFailureKind.calendarList:
          case GoogleCalendarSourceFailureKind.events:
          case GoogleCalendarSourceFailureKind.malformedResponse:
          case null:
            return ' Calendars could not be loaded.';
        }
    }
  }

  String _authorizationIssueText(GoogleCalendarAuthorizationIssue? issue) {
    switch (issue) {
      case GoogleCalendarAuthorizationIssue.nexecuteUserMissing:
        return 'Sign in to Nexecute before connecting Google Calendar.';
      case GoogleCalendarAuthorizationIssue.nexecuteAccountIsNotGoogle:
        return 'Use a Google Nexecute account to connect Google Calendar.';
      case GoogleCalendarAuthorizationIssue.accountMismatch:
        return 'Choose the same Google account used for Nexecute.';
      case GoogleCalendarAuthorizationIssue.scopesDenied:
        return 'Calendar permission was not granted. Try again to allow access.';
      case GoogleCalendarAuthorizationIssue.accessTokenUnavailable:
        return 'Google Calendar access expired. Connect again.';
      case GoogleCalendarAuthorizationIssue.providerUnavailable:
        return 'Google sign-in is temporarily unavailable. Try again.';
      case GoogleCalendarAuthorizationIssue.unsupported:
        return 'Google Calendar is not supported on this device.';
      case null:
        return 'Google Calendar could not connect. Try again.';
    }
  }
}

class _CalendarSelectionDialog extends StatefulWidget {
  const _CalendarSelectionDialog({
    required this.calendars,
    required this.selectedIds,
  });

  final List<GoogleCalendarInfo> calendars;
  final Set<String> selectedIds;

  @override
  State<_CalendarSelectionDialog> createState() =>
      _CalendarSelectionDialogState();
}

class _CalendarSelectionDialogState extends State<_CalendarSelectionDialog> {
  late final Set<String> _selected = {...widget.selectedIds};
  String? _limitMessage;

  @override
  Widget build(BuildContext context) {
    final dialogHeight = math.min(
      440.0,
      MediaQuery.sizeOf(context).height * 0.55,
    );
    return AlertDialog(
      scrollable: true,
      title: const Text('Manage calendars'),
      content: SizedBox(
        width: 520,
        height: dialogHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose up to ${GoogleCalendarSource.maxSelectedCalendars} calendars.',
            ),
            if (_limitMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _limitMessage!,
                key: const Key('google-calendar-selection-limit'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            if (widget.calendars.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No calendars are available.'),
              )
            else
              Expanded(
                child: Scrollbar(
                  child: ListView.builder(
                    itemCount: widget.calendars.length,
                    itemBuilder: (context, index) {
                      final calendar = widget.calendars[index];
                      final checked = _selected.contains(calendar.id);
                      return CheckboxListTile(
                        key: Key('google-calendar-option-$index'),
                        contentPadding: EdgeInsets.zero,
                        value: checked,
                        controlAffinity: ListTileControlAffinity.trailing,
                        secondary: _CalendarColorSwatch(calendar: calendar),
                        title: Text(calendar.name),
                        subtitle: Text(
                          [
                            if (calendar.isPrimary) 'Primary',
                            checked ? 'Enabled' : 'Disabled',
                          ].join(' - '),
                        ),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              if (_selected.length >=
                                  GoogleCalendarSource.maxSelectedCalendars) {
                                _limitMessage =
                                    'You can select up to ${GoogleCalendarSource.maxSelectedCalendars} calendars.';
                                return;
                              }
                              _selected.add(calendar.id);
                            } else {
                              _selected.remove(calendar.id);
                            }
                            _limitMessage = null;
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('google-calendar-save-selection'),
          onPressed: () => Navigator.pop(context, Set.of(_selected)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _CalendarColorSwatch extends StatelessWidget {
  const _CalendarColorSwatch({required this.calendar});

  final GoogleCalendarInfo calendar;

  @override
  Widget build(BuildContext context) {
    final colorValue = calendar.colorValue;
    final color =
        colorValue == null
            ? Theme.of(context).colorScheme.outline
            : Color(colorValue);
    return Semantics(
      label: '${calendar.name} calendar color',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      ),
    );
  }
}

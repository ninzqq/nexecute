import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

typedef OpenNoteLink = Future<bool> Function(Uri uri);

class LinkifiedText extends StatefulWidget {
  const LinkifiedText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.selectable = false,
    this.onOpenLink,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final bool selectable;
  final OpenNoteLink? onOpenLink;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  static final _urlPattern = RegExp(
    r'(?:(?:https?://)|(?:www\.))[^\s<>()]+',
    caseSensitive: false,
  );
  static final _trailingPunctuation = RegExp(r'[.,;:!?\]\}]+$');

  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final primary = Theme.of(context).colorScheme.primary;
    final linkStyle = baseStyle.copyWith(
      color: primary,
      decoration: TextDecoration.underline,
      decorationColor: primary,
    );
    final span = TextSpan(children: _buildSpans(linkStyle));

    if (widget.selectable) {
      return SelectableText.rich(
        span,
        style: baseStyle,
        maxLines: widget.maxLines,
      );
    }

    return Text.rich(
      span,
      style: baseStyle,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }

  List<InlineSpan> _buildSpans(TextStyle linkStyle) {
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in _urlPattern.allMatches(widget.text)) {
      var linkEnd = match.end;
      final matchedText = match.group(0)!;
      final trailing = _trailingPunctuation.firstMatch(matchedText);
      if (trailing != null) linkEnd -= trailing.group(0)!.length;
      if (linkEnd <= match.start) continue;

      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }

      final label = widget.text.substring(match.start, linkEnd);
      final uri = Uri.parse(
        label.toLowerCase().startsWith('www.') ? 'https://$label' : label,
      );
      final recognizer = TapGestureRecognizer()..onTap = () => _open(uri);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: label,
          style: linkStyle,
          recognizer: recognizer,
          mouseCursor: SystemMouseCursors.click,
        ),
      );
      cursor = linkEnd;
    }

    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return spans;
  }

  Future<void> _open(Uri uri) async {
    try {
      final opened =
          await (widget.onOpenLink?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened && mounted) _showOpenError();
    } catch (_) {
      if (mounted) _showOpenError();
    }
  }

  void _showOpenError() {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('Could not open link')));
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }
}

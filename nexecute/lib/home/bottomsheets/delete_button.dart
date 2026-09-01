import 'package:flutter/material.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/repositories/note_repository.dart';
import 'package:nexecute/shared/event_delete_confirmation.dart';
import 'package:provider/provider.dart';

class DeleteButton extends StatelessWidget {
  final Quicxec? quicxec;
  final Event? event;

  const DeleteButton({super.key, required this.quicxec, required this.event});

  @override
  Widget build(BuildContext context) {
    final existsQuicxec = quicxec != null && quicxec!.id.isNotEmpty;
    final existsEvent = event != null && event!.id.isNotEmpty;

    return IconButton(
      onPressed: () async {
        if (quicxec != null && existsQuicxec) {
          context.read<NoteRepository>().toggleTrashed(quicxec!);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quicxec moved to trash')),
          );
          Navigator.popUntil(context, (route) => route.isFirst);
        } else if (event != null && existsEvent) {
          final confirmed = await confirmEventDeletion(context, event!);
          if (!confirmed || !context.mounted) return;

          await context.read<EventRepository>().deleteEvent(event!);
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Event deleted')));
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      },
      icon: Icon(
        Icons.delete_forever,
        color: existsQuicxec || existsEvent ? Colors.red : Colors.white12,
      ),
    );
  }
}

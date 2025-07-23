import 'package:flutter/material.dart';
import 'package:nexecute/services/firestore.dart';
import 'package:nexecute/shared/styles.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/home/bottomsheets/utils.dart';

class DeleteButton extends StatelessWidget {
  final Quicxec? quicxec;
  final Event? event;
  final List<Quicxec> quicxecs;
  final List<Event> events;

  const DeleteButton({
    super.key,
    required this.quicxec,
    required this.event,
    required this.quicxecs,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    final existsQuicxec = existingQuicxec(quicxecs, quicxec);
    final existsEvent = existingEvent(events, event);

    return IconButton(
      onPressed: () {
        if (quicxec != null && existsQuicxec) {
          FirestoreService().moveCurrentlyOpenQuicxec(quicxec!);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: snackBarBgColor,
              content: Text('Quicxec moved to trash'),
            ),
          );
          Navigator.popUntil(context, (route) => route.isFirst);
        } else if (event != null && existsEvent) {
          FirestoreService().deleteCurrentlyOpenEvent(event!);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: snackBarBgColor,
              content: Text('Event deleted'),
            ),
          );
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
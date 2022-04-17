import 'package:flutter/material.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:provider/provider.dart';

class ExecutesList extends StatelessWidget {
  const ExecutesList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        StreamProvider(
          create: (_) => FirestoreService().streamCount(),
          catchError: (_, err) => Count(),
          initialData: Count(),
        ),
      ],
      child: Container(
        color: darkestCyan2,
        child: const Center(
          child: Text('Second'),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:nexecute/services/services.dart';
import 'package:provider/provider.dart';

class CountPage extends StatelessWidget {
  const CountPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Count count = Provider.of<Count>(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 140),
            child: Text(
              'You have pushed the button this many times:',
              style: Theme.of(context).textTheme.bodyText2,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(count.count.toString(),
                style: Theme.of(context).textTheme.headline1),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 100),
            child: SizedBox(
              width: 100,
              height: 100,
              child: FittedBox(
                child: FloatingActionButton(
                  onPressed: FirestoreService().updateUserPressCount,
                  tooltip: 'Add +1 to your counter',
                  backgroundColor: const Color.fromARGB(255, 20, 170, 170),
                  child: const Icon(Icons.add_sharp),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

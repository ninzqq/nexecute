import 'package:flutter/material.dart';
import 'package:nexecute/services/services.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/shared/shared.dart';

class CountScreen extends StatelessWidget {
  const CountScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Count count = Provider.of<Count>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Button pressinks'),
        backgroundColor: appBarDarkCyan,
      ),
      body: Container(
        color: bgDarkCyan,
        child: Center(
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
                padding: const EdgeInsets.all(10),
                child: Text(count.count.toString(),
                    style: Theme.of(context).textTheme.headline1),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 100),
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: FittedBox(
                    child: FloatingActionButton(
                      onPressed: FirestoreService().updateUserPressCount,
                      tooltip: 'Add +1 to your counter',
                      backgroundColor: primaryButtonCyan,
                      child: const Icon(Icons.add_sharp),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

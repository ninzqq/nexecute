import 'package:flutter/material.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Count count = Provider.of<Count>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execs'),
      ),
      drawer: const MainDrawer(),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'You have pushed the button this many times:',
                style: Theme.of(context).textTheme.bodyText2,
              ),
              Text(count.count.toString(),
                  style: Theme.of(context).textTheme.headline1),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: FirestoreService().updateUserPressCount,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/repositories/count_repository.dart';
import 'package:nexecute/shared/data_state_placeholder.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/models/count.dart';

class CountScreen extends StatelessWidget {
  const CountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DataState<Count>>();
    return Scaffold(
      appBar: AppBar(title: const Text('Button pressinks')),
      body: switch (state) {
        DataLoading<Count>() => const DataStatePlaceholder(
          presentation: DataStatePresentation.loading,
          title: 'Loading count…',
        ),
        DataUnauthenticated<Count>() => const DataStatePlaceholder(
          presentation: DataStatePresentation.unauthenticated,
        ),
        DataFailure<Count>() => const DataStatePlaceholder(
          presentation: DataStatePresentation.failure,
          title: 'Could not load count',
        ),
        DataEmpty<Count>(:final value) => _CountContent(count: value),
        DataReady<Count>(:final value) => _CountContent(count: value),
      },
    );
  }
}

class _CountContent extends StatelessWidget {
  const _CountContent({required this.count});

  final Count count;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 140),
            child: Text(
              'You have pushed the button this many times:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              count.count.toString(),
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 100),
            child: SizedBox(
              width: 120,
              height: 120,
              child: FittedBox(
                child: FloatingActionButton(
                  onPressed: context.read<CountRepository>().increment,
                  tooltip: 'Add +1 to your counter',
                  child: const Icon(Icons.add_sharp),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

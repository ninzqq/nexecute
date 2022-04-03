import 'package:flutter/material.dart';
import 'package:nexecute/count/countscreen.dart';

class ExecutesPagesPageView extends StatelessWidget {
  const ExecutesPagesPageView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final PageController controller = PageController();
    //var asd = 0.0;
    return Column(
      children: [
        PageView(
          controller: controller,
          //onPageChanged: (pageindex) {},
          children: const <Widget>[
            Center(
              child: Text('First Page'),
            ),
            Center(
              child: Text('Second Page'),
            ),
            Center(
              child: Text('Third Page'),
            ),
          ],
        ),
      ],
    );
  }
}

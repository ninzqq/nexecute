import 'package:flutter/material.dart';
import 'package:nexecute/count/countpage.dart';

class ExecutePagesPageView extends StatelessWidget {
  const ExecutePagesPageView({Key? key}) : super(key: key);

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
            CountPage(),
            Center(
              child: Text('Third Page'),
            ),
          ],
        ),
      ],
    );
  }
}

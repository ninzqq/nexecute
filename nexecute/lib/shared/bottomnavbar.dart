import 'package:flutter/material.dart';
import 'package:nexecute/services/services.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/shared/colors.dart';
import 'package:nexecute/home/homescreen.dart';

class BottomNavBar extends StatelessWidget {
  final Function changePage;
  const BottomNavBar({Key? key, required this.changePage}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var homePageIndex = Provider.of<HomeTabIndex>(context, listen: true);
    final Size size = MediaQuery.of(context).size;
    const double navBarHeight = 70.0;

    return Positioned(
      bottom: 0,
      left: 0,
      child: SizedBox(
        width: size.width,
        height: navBarHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: Size(size.width, navBarHeight),
              painter: BottomNavBarPainter(),
            ),
            Center(
              heightFactor: 0.6,
              child: SizedBox(
                width: 63,
                height: 63,
                child: FloatingActionButton(
                  backgroundColor: niceCyan,
                  child: const Icon(Icons.add_rounded),
                  elevation: 0.1,
                  onPressed: () {},
                ),
              ),
            ),
            SizedBox(
              width: size.width,
              height: navBarHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () {
                      homePageIndex.changeIndex(0);
                      changePage(
                        0,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.fastLinearToSlowEaseIn,
                      );
                    },
                    icon: const Icon(Icons.calendar_month_outlined),
                    color: homePageIndex.idx == 0
                        ? niceCyan
                        : Colors.grey.shade400,
                  ),
                  Container(
                    width: size.width * 0.12,
                  ),
                  IconButton(
                    onPressed: () {
                      homePageIndex.changeIndex(1);
                      changePage(
                        1,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.fastLinearToSlowEaseIn,
                      );
                    },
                    icon: const Icon(Icons.list_alt_sharp),
                    color: homePageIndex.idx == 1
                        ? niceCyan
                        : Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BottomNavBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = darkestCyan
      ..style = PaintingStyle.fill;

    Path path = Path();
    path.moveTo(0, 30); // Start
    path.quadraticBezierTo(size.width * 0.20, 0, size.width * 0.35, 0);
    path.quadraticBezierTo(size.width * 0.40, 0, size.width * 0.40, 20);
    path.arcToPoint(Offset(size.width * 0.60, 20),
        radius: const Radius.circular(20.0), clockwise: false);
    path.quadraticBezierTo(size.width * 0.60, 0, size.width * 0.65, 0);
    path.quadraticBezierTo(size.width * 0.80, 0, size.width, 30);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, 20);
    canvas.drawShadow(path, Colors.black, 5, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

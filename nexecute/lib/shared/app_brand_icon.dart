import 'package:flutter/material.dart';

class NexecuteAppIcon extends StatelessWidget {
  const NexecuteAppIcon({super.key, required this.size});

  static const assetName = 'assets/branding/nexecute_icon_foreground.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetName,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Nexecute',
    );
  }
}

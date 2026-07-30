import 'package:flutter/material.dart';

class GuideScroller extends StatelessWidget {
  final Widget child;
  final Axis scrollDirection;

  const GuideScroller({
    super.key,
    required this.child,
    this.scrollDirection = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: scrollDirection,
      physics: const BouncingScrollPhysics(),
      child: child,
    );
  }
}
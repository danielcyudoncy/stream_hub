import 'package:flutter/material.dart';

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsetsGeometry? padding;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.crossAxisSpacing = 12.0,
    this.mainAxisSpacing = 12.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    int crossAxisCount;
    if (width < 600) {
      crossAxisCount = 2;
    } else if (width < 1024) {
      crossAxisCount = 3;
    } else if (width < 1440) {
      crossAxisCount = 4;
    } else {
      crossAxisCount = 5;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding ?? EdgeInsets.zero,
      itemCount: children.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: 0.75,
      ),
      itemBuilder: (context, index) => children[index],
    );
  }
}
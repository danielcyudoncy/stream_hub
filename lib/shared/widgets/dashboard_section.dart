import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import 'section_header.dart';

class DashboardSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showDivider;
  final Widget child;

  const DashboardSection({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showDivider = true,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          subtitle: subtitle,
          trailing: trailing,
        ),
        AppSpacing.heightXS,
        child,
        if (showDivider) ...[
          AppSpacing.heightMD,
          const Divider(height: 1),
          AppSpacing.heightMD,
        ],
      ],
    );
  }
}
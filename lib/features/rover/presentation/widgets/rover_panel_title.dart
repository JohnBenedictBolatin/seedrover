import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';

class RoverPanelTitle extends StatelessWidget {
  const RoverPanelTitle({
    required this.title,
    super.key,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTypography.sectionHeading);
  }
}

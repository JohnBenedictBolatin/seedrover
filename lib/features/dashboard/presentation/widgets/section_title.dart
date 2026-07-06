import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    super.key,
    this.mono = false,
  });

  final String title;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return AnimatedTypingText(
      title,
      style: mono
          ? AppTypography.monoSectionHeading
          : AppTypography.sectionHeading,
    );
  }
}

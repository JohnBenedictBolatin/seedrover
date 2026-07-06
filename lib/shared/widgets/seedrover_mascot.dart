import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';

enum SeedRoverMascotExpression {
  neutral('neutral'),
  happy('happy'),
  success('success'),
  warning('warning'),
  error('error'),
  assistant('assistant'),
  dashboard('dashboard'),
  emptyCurious('empty_curious'),
  thinking('thinking'),
  working('working'),
  loading('loading');

  const SeedRoverMascotExpression(this.assetName);

  final String assetName;

  String get assetPath => 'assets/images/mascot/$assetName.png';
}

class SeedRoverMascot extends StatelessWidget {
  const SeedRoverMascot({
    super.key,
    this.expression = SeedRoverMascotExpression.neutral,
    this.size = 96,
    this.alignment = Alignment.center,
  });

  final SeedRoverMascotExpression expression;
  final double size;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      expression.assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      alignment: alignment,
      filterQuality: FilterQuality.none,
    );
  }
}

class SeedRoverMascotMessage extends StatelessWidget {
  const SeedRoverMascotMessage({
    required this.message,
    super.key,
    this.expression = SeedRoverMascotExpression.thinking,
  });

  final String message;
  final SeedRoverMascotExpression expression;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SeedRoverMascot(expression: expression, size: 64),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: AppTypography.body)),
      ],
    );
  }
}

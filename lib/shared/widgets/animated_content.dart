import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AnimatedTypingText extends StatelessWidget {
  const AnimatedTypingText(
    this.text, {
    required this.style,
    super.key,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      style: style,
    );
  }
}

class AnimatedMetricText extends StatelessWidget {
  const AnimatedMetricText(
    this.text, {
    required this.style,
    super.key,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.duration = const Duration(milliseconds: 200),
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      style: style,
    );
  }
}

class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    required this.value,
    super.key,
    this.minHeight = 6,
    this.color,
    this.backgroundColor,
    this.duration = const Duration(milliseconds: 240),
  });

  final double value;
  final double minHeight;
  final Color? color;
  final Color? backgroundColor;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0, 1).toDouble()),
      duration:
          MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return LinearProgressIndicator(
          value: animatedValue,
          minHeight: minHeight,
          color: color ?? AppColors.primaryGreen,
          backgroundColor: backgroundColor ?? AppColors.inactiveBorder,
        );
      },
    );
  }
}

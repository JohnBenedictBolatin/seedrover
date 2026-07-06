import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AnimatedTypingText extends StatefulWidget {
  const AnimatedTypingText(
    this.text, {
    required this.style,
    super.key,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.stepDuration = const Duration(milliseconds: 22),
    this.startDelay = const Duration(milliseconds: 80),
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final Duration stepDuration;
  final Duration startDelay;

  @override
  State<AnimatedTypingText> createState() => _AnimatedTypingTextState();
}

class _AnimatedTypingTextState extends State<AnimatedTypingText> {
  Timer? _startTimer;
  Timer? _timer;
  int _visibleCharacters = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void didUpdateWidget(covariant AnimatedTypingText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.text != widget.text) {
      _startTyping();
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final characterCount = widget.text.length;
    final safeVisibleCharacters =
        _visibleCharacters.clamp(0, characterCount).toInt();
    final visibleText = widget.text.substring(0, safeVisibleCharacters);

    return Stack(
      children: [
        Opacity(
          opacity: 0,
          child: Text(
            widget.text,
            maxLines: widget.maxLines,
            overflow: widget.overflow,
            textAlign: widget.textAlign,
            style: widget.style,
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: _alignmentFor(widget.textAlign),
            child: Text(
              visibleText,
              maxLines: widget.maxLines,
              overflow: widget.overflow,
              textAlign: widget.textAlign,
              style: widget.style,
            ),
          ),
        ),
      ],
    );
  }

  void _startTyping() {
    _startTimer?.cancel();
    _timer?.cancel();
    _visibleCharacters = 0;

    if (widget.text.isEmpty) {
      return;
    }

    _startTimer = Timer(widget.startDelay, () {
      if (!mounted) {
        return;
      }

      _timer = Timer.periodic(widget.stepDuration, (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        final length = widget.text.length;

        if (_visibleCharacters >= length) {
          timer.cancel();
          return;
        }

        setState(() {
          _visibleCharacters += 1;
        });
      });
    });
  }

  Alignment _alignmentFor(TextAlign? textAlign) {
    if (textAlign == TextAlign.center) {
      return Alignment.center;
    }

    if (textAlign == TextAlign.right || textAlign == TextAlign.end) {
      return Alignment.centerRight;
    }

    return Alignment.centerLeft;
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
    this.duration = const Duration(milliseconds: 760),
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final parsed = _ParsedMetric.tryParse(text);

    if (parsed == null) {
      return AnimatedTypingText(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: parsed.value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final displayed = parsed.decimals == 0
            ? value.round().toString()
            : value.toStringAsFixed(parsed.decimals);

        return Text(
          '${parsed.prefix}$displayed${parsed.suffix}',
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
          style: style,
        );
      },
    );
  }
}

class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    required this.value,
    super.key,
    this.minHeight = 6,
    this.color = AppColors.primaryGreen,
    this.backgroundColor = AppColors.inactiveBorder,
    this.duration = const Duration(milliseconds: 820),
  });

  final double value;
  final double minHeight;
  final Color color;
  final Color backgroundColor;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0, 1).toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return LinearProgressIndicator(
          value: animatedValue,
          minHeight: minHeight,
          color: color,
          backgroundColor: backgroundColor,
        );
      },
    );
  }
}

class _ParsedMetric {
  const _ParsedMetric({
    required this.prefix,
    required this.value,
    required this.suffix,
    required this.decimals,
  });

  final String prefix;
  final double value;
  final String suffix;
  final int decimals;

  static _ParsedMetric? tryParse(String text) {
    final match = RegExp(r'^([^0-9.-]*)(-?\d+(?:\.\d+)?)(.*)$')
        .firstMatch(text.trim());

    if (match == null) {
      return null;
    }

    final numericText = match.group(2)!;
    final value = double.tryParse(numericText);

    if (value == null) {
      return null;
    }

    return _ParsedMetric(
      prefix: match.group(1) ?? '',
      value: value,
      suffix: match.group(3) ?? '',
      decimals: numericText.contains('.')
          ? numericText.split('.').last.length
          : 0,
    );
  }
}

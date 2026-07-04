import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../../shared/widgets/status_badge.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    required this.fullName,
    required this.roleName,
    required this.timestamp,
    super.key,
  });

  final String fullName;
  final String roleName;
  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [
                AppColors.buttonGradientStart,
                AppColors.buttonGradientEnd,
              ],
            ).createShader(bounds);
          },
          child: Text(
            '${_greeting(timestamp)}, ${_firstName(fullName)}!',
            style: AppTypography.displayHeading.copyWith(
              fontSize: 28,
              height: 34 / 28,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            StatusBadge(label: roleName),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${DateTimeFormatter.formatDate(timestamp)} '
                '${DateTimeFormatter.formatTime(timestamp)}',
                textAlign: TextAlign.end,
                style: AppTypography.monoSmall.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _firstName(String value) {
    return value.trim().split(' ').first;
  }

  String _greeting(DateTime value) {
    if (value.hour < 12) {
      return 'Good morning';
    }

    if (value.hour < 18) {
      return 'Good afternoon';
    }

    return 'Good evening';
  }
}

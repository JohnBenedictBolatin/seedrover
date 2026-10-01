import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final foreground =
        AppColors.isLight ? Colors.white : const Color(0xFF102318);
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          foregroundColor: foreground,
          disabledForegroundColor: foreground,
          disabledBackgroundColor: AppColors.mutedText,
          textStyle: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            fontVariations: const [FontVariation('wght', 600)],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: isLoading
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : Text(label),
      ),
    );
  }
}

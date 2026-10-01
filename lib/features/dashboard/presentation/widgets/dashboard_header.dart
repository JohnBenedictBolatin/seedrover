import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../../shared/widgets/page_header_actions.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({
    this.onGradient = false,
    super.key,
  });

  final bool onGradient;

  Color get _foregroundColor =>
      onGradient ? Colors.white : AppColors.primaryText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPageHeader(
      title: 'Dashboard',
      titleColor: _foregroundColor,
      actions: PageHeaderActions(
        foregroundColor: onGradient ? Colors.white : null,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/history_pagination.dart';

class CropHistoryButton extends StatelessWidget {
  const CropHistoryButton({this.client, this.onPressed, super.key})
      : assert(client != null || onPressed != null);

  final SupabaseClient? client;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.heroGradientColors.first,
                AppColors.heroGradientColors.last,
              ],
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: onPressed ??
                  () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _CropHistorySheet(client: client!),
                      ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'View Crop History',
                      style: AppTypography.small.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _CropHistorySheet extends StatefulWidget {
  const _CropHistorySheet({required this.client});

  final SupabaseClient client;

  @override
  State<_CropHistorySheet> createState() => _CropHistorySheetState();
}

class _CropHistorySheetState extends State<_CropHistorySheet> {
  static const _pageSize = 5;

  int _page = 0;
  late Future<_HistoryPage> _records = _loadPage();

  Future<_HistoryPage> _loadPage() async {
    final results = await Future.wait<Object>([
      widget.client
          .from('crop_outcomes')
          .select(
            'id,crop_name,outcome,reason,quantity,recorded_at,recorded_by',
          )
          .order('recorded_at', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1),
      widget.client.from('crop_outcomes').count(CountOption.exact),
    ]);
    final rows = results[0] as List<dynamic>;
    final performerIds = rows
        .map((value) => (value as Map<String, dynamic>)['recorded_by'])
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final names = <String, String>{};
    if (performerIds.isNotEmpty) {
      try {
        final performers = await widget.client.rpc(
          'crop_performer_names',
          params: {'p_performer_ids': performerIds},
        ) as List<dynamic>;
        for (final value in performers) {
          final row = value as Map<String, dynamic>;
          final id = row['performer_id'] as String?;
          final name = (row['full_name'] as String?)?.trim();
          if (id != null && name?.isNotEmpty == true) names[id] = name!;
        }
      } catch (_) {
        // Keep the history visible if performer names are unavailable.
      }
    }
    return _HistoryPage(
      rows: [
        for (final value in rows)
          <String, dynamic>{
            ...(value as Map<String, dynamic>),
            'recorded_by_name':
                names[(value as Map<String, dynamic>)['recorded_by']],
          },
      ],
      total: results[1] as int,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: FractionallySizedBox(
          heightFactor: .88,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primaryBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inactiveBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Crop History',
                                style: AppTypography.sectionHeading),
                            Text('Recorded crop outcomes',
                                style: AppTypography.caption),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close crop history',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: FutureBuilder<_HistoryPage>(
                    future: _records,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return _HistoryMessage(
                          icon: Icons.cloud_off_outlined,
                          message:
                              'Crop history could not be loaded. Check your connection and try again.',
                          action: TextButton.icon(
                            onPressed: () =>
                                setState(() => _records = _loadPage()),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        );
                      }
                      final result = snapshot.data!;
                      if (result.rows.isEmpty) {
                        return _HistoryMessage(
                          icon: Icons.history_rounded,
                          message: 'No crop outcomes have been recorded yet.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.xs,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        itemCount: result.rows.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) =>
                            _OutcomeTile(row: result.rows[index]),
                      );
                    },
                  ),
                ),
                FutureBuilder<_HistoryPage>(
                  future: _records,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.hasError) {
                      return const SizedBox(height: AppSpacing.md);
                    }
                    final total = snapshot.data!.total;
                    return Padding(
                      padding: EdgeInsets.zero,
                      child: HistoryPagination(
                        pageIndex: _page,
                        totalRecords: total,
                        pageSize: _pageSize,
                        onPageChanged: (page) => setState(() {
                          _page = page;
                          _records = _loadPage();
                        }),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryPage {
  const _HistoryPage({required this.rows, required this.total});

  final List<dynamic> rows;
  final int total;
}

class _OutcomeTile extends StatelessWidget {
  const _OutcomeTile({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final recordedAt = DateTime.tryParse(row['recorded_at']?.toString() ?? '');
    final recorder = row['recorded_by_name'] as String? ??
        (row['recorded_by'] == null ? 'Not recorded' : 'Former user');
    final quantity = row['quantity'];
    final outcome = row['outcome']?.toString() ?? 'Outcome recorded';
    return _HistoryCard(
      icon: outcome.toLowerCase() == 'harvested'
          ? Icons.spa_outlined
          : Icons.info_outline_rounded,
      title:
          '${row['crop_name']?.toString() ?? 'Crop'} · ${outcome == 'Failed' ? 'Closed without harvest' : outcome}',
      subtitle: quantity == null ? '' : '$quantity kg',
      detail: [
        if ((row['reason']?.toString().trim().isNotEmpty ?? false))
          row['reason'].toString(),
        'By $recorder${recordedAt == null ? '' : ' · ${_formatDate(recordedAt)}'}',
      ].join('\n'),
      tone: outcome.toLowerCase() == 'harvested'
          ? AppColors.success
          : AppColors.warning,
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String detail;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.inactiveBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: tone, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  if (subtitle.isNotEmpty) ...[
                    Text(subtitle,
                        style: AppTypography.small.copyWith(color: tone)),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Text(detail, style: AppTypography.caption),
                ],
              ),
            ),
          ],
        ),
      );
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage(
      {required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.primaryGreen, size: 36),
              const SizedBox(height: AppSpacing.sm),
              Text(message,
                  textAlign: TextAlign.center, style: AppTypography.body),
              if (action != null) action!,
            ],
          ),
        ),
      );
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

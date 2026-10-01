import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/widgets/task_form.dart';
import '../../data/models/crop_model.dart';
import '../../data/repositories/crop_repository.dart';

class CropPhotoHistory extends StatelessWidget {
  const CropPhotoHistory(
      {required this.crop, required this.growthOnly, super.key});
  final CropModel crop;
  final bool growthOnly;

  @override
  Widget build(BuildContext context) {
    final records = crop.maintenanceHistory
        .where((record) => growthOnly
            ? record.activity == CropMaintenanceActivity.stageObserved
            : record.activity != CropMaintenanceActivity.stageObserved &&
                record.photoPaths.isNotEmpty)
        .toList()
      ..sort((a, b) => b.performedAt.compareTo(a.performedAt));
    final illustrated =
        records.where((record) => record.photoPaths.isNotEmpty).toList();
    if (!growthOnly && records.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                growthOnly ? 'Growth observations' : 'Care photos',
                style: AppTypography.sectionHeading,
              ),
            ),
            if (illustrated.length >= 2)
              IconButton(
                tooltip: 'Compare growth photos',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _PhotoComparison(records: illustrated),
                  ),
                ),
                icon: const Icon(Icons.compare_arrows_rounded),
              ),
          ],
        ),
        if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text('No growth observations have been recorded yet.',
                style: AppTypography.small),
          ),
        for (final record in records) _CropPhotoRecordTile(record: record),
      ],
    );
  }
}

class _CropPhotoRecordTile extends StatelessWidget {
  const _CropPhotoRecordTile({required this.record});

  final CropMaintenanceRecord record;

  @override
  Widget build(BuildContext context) {
    final title = record.observedStage ?? record.activity.label;
    final date =
        DateFormat.yMMMd().add_jm().format(record.performedAt.toLocal());
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      color: AppColors.secondaryBackground,
      child: ExpansionTile(
        leading: Icon(
          record.photoPaths.isEmpty
              ? Icons.eco_outlined
              : Icons.photo_library_outlined,
          color: AppColors.primaryGreen,
        ),
        title: Text(title, style: AppTypography.body),
        subtitle:
            Text('$date · ${record.performedBy}', style: AppTypography.caption),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          if (record.notes.trim().isNotEmpty) Text(record.notes),
          if (record.observedStage == null &&
              (record.quantity != null || record.material != null))
            Text(
                [
                  if (record.quantity != null)
                    'Quantity: ${record.quantity} ${record.unit ?? ''}'.trim(),
                  if (record.material?.trim().isNotEmpty == true)
                    'Material: ${record.material}',
                ].join(' · '),
                style: AppTypography.small),
          if (record.photoPaths.isEmpty)
            Text('No photo attached', style: AppTypography.caption),
          for (final path in record.photoPaths)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text(title)),
                      body: SafeArea(
                        child: ListView(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          children: [
                            Text(date, style: AppTypography.numericSmall),
                            const SizedBox(height: AppSpacing.md),
                            InteractiveViewer(
                                child: JournalPhoto(path: path, height: 400)),
                            if (record.notes.isNotEmpty) Text(record.notes),
                            const Text(
                              'Field observation photo; not a verified health diagnosis.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                child: JournalPhoto(path: path),
              ),
            ),
        ],
      ),
    );
  }
}

class JournalPhoto extends ConsumerStatefulWidget {
  const JournalPhoto({required this.path, this.height = 180, super.key});
  final String path;
  final double height;
  @override
  ConsumerState<JournalPhoto> createState() => _JournalPhotoState();
}

class _JournalPhotoState extends ConsumerState<JournalPhoto> {
  late Future<String> _url;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _url = ref.read(cropRepositoryProvider).signedJournalPhoto(widget.path);
  }

  @override
  void didUpdateWidget(covariant JournalPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _reload();
  }

  Widget _error() =>
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.broken_image_outlined),
        const Text('Photo unavailable'),
        TextButton(
            onPressed: () => setState(_reload),
            child: const Text('Retry photo')),
      ]);
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: FutureBuilder<String>(
              future: _url,
              builder: (context, snapshot) {
                if (snapshot.hasError) return _error();
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Image.network(snapshot.data!,
                    fit: BoxFit.contain,
                    semanticLabel: 'Field observation photo',
                    errorBuilder: (_, __, ___) => _error(),
                    loadingBuilder: (_, image, progress) => progress == null
                        ? image
                        : const Center(child: CircularProgressIndicator()));
              })));
}

class _PhotoComparison extends StatefulWidget {
  const _PhotoComparison({required this.records});
  final List<CropMaintenanceRecord> records;
  @override
  State<_PhotoComparison> createState() => _PhotoComparisonState();
}

class _PhotoComparisonState extends State<_PhotoComparison> {
  int _left = 0, _right = 1;
  @override
  Widget build(BuildContext context) {
    Widget panel(int selected, ValueChanged<int> select) {
      final record = widget.records[selected];
      return TaskFields(children: [
        AppSelector<int>(
            key: ValueKey(selected),
            value: selected,
            decoration: const InputDecoration(labelText: 'Observation'),
            items: [
              for (var i = 0; i < widget.records.length; i++)
                DropdownMenuItem(
                    value: i,
                    child: Text(
                        '${DateFormat.yMMMd().add_jm().format(widget.records[i].performedAt.toLocal())} · ${widget.records[i].observedStage ?? widget.records[i].activity.label}'))
            ],
            onChanged: (value) {
              if (value != null) setState(() => select(value));
            }),
        for (final path in record.photoPaths)
          JournalPhoto(path: path, key: ValueKey(path), height: 240),
        if (record.notes.isNotEmpty) Text(record.notes),
      ]);
    }

    return Scaffold(
        appBar: AppBar(title: const Text('Compare observations')),
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(builder: (context, constraints) {
                  final left = panel(_left, (value) {
                    if (value == _right) _right = _left;
                    _left = value;
                  });
                  final right = panel(_right, (value) {
                    if (value == _left) _left = _right;
                    _right = value;
                  });
                  return TaskFields(children: [
                    const Text(
                        'Compare dated observations. Photos do not establish a verified health diagnosis.'),
                    if (constraints.maxWidth >= 600)
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: left),
                            const SizedBox(width: 16),
                            Expanded(child: right)
                          ])
                    else ...[left, const Divider(), right],
                  ]);
                }))));
  }
}

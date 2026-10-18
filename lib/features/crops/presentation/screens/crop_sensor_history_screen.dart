import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/history_pagination.dart';
import '../../data/models/crop_model.dart';
import '../../providers/crop_providers.dart';
import '../../../../shared/widgets/content_skeleton.dart';
import '../../../../shared/widgets/initial_loading_skeleton.dart';

class CropSensorHistoryScreen extends ConsumerStatefulWidget {
  const CropSensorHistoryScreen({
    required this.cropId,
    this.embedded = false,
    this.enabled = true,
    super.key,
  });

  final String cropId;
  final bool embedded;
  final bool enabled;

  @override
  ConsumerState<CropSensorHistoryScreen> createState() =>
      _CropSensorHistoryScreenState();
}

class _CropSensorHistoryScreenState
    extends ConsumerState<CropSensorHistoryScreen> {
  static const _pageSize = 6;
  int _pageIndex = 0;

  @override
  void didUpdateWidget(covariant CropSensorHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cropId != widget.cropId) _pageIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const Center(child: Text('Open Sensors to load crop readings.'));
    }
    final readings = ref.watch(cropSensorHistoryProvider(widget.cropId));
    final body = SafeArea(
      child: readings.when(
        loading: () => const InitialLoadingSkeleton(
          skeleton: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                SkeletonCard(height: 72, children: []),
                SizedBox(height: AppSpacing.md),
                SkeletonCard(height: 72, children: []),
                SizedBox(height: AppSpacing.md),
                SkeletonCard(height: 72, children: []),
              ],
            ),
          ),
          label: 'Loading sensor history…',
        ),
        error: (_, __) => _SensorHistoryMessage(
          icon: Icons.cloud_off_outlined,
          message: 'Sensor history could not be loaded.',
          action: FilledButton.icon(
            onPressed: () =>
                ref.invalidate(cropSensorHistoryProvider(widget.cropId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _SensorHistoryMessage(
              icon: Icons.sensors_off_outlined,
              message: 'No sensor readings are linked to this crop yet.',
            );
          }
          final pageCount = (items.length / _pageSize).ceil();
          final pageIndex = _pageIndex.clamp(0, pageCount - 1);
          final start = pageIndex * _pageSize;
          final visibleReadings =
              items.skip(start).take(_pageSize).toList(growable: false);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: _LatestSensorSummary(reading: items.first),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Reading history',
                        style: AppTypography.sectionHeading,
                      ),
                    ),
                    Text(
                      items.length == 100
                          ? 'Latest 100'
                          : '${items.length} readings',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  itemCount: visibleReadings.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _SensorReadingRow(reading: visibleReadings[index]),
                ),
              ),
              if (items.length > _pageSize)
                HistoryPagination(
                  pageIndex: pageIndex,
                  totalRecords: items.length,
                  pageSize: _pageSize,
                  onPageChanged: (page) => setState(() => _pageIndex = page),
                ),
            ],
          );
        },
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Sensor history')),
      body: body,
    );
  }
}

class _LatestSensorSummary extends StatelessWidget {
  const _LatestSensorSummary({required this.reading});

  final CropSensorReading reading;

  @override
  Widget build(BuildContext context) {
    final recordedAt = reading.recordedAt.toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Latest sensor check',
          style: AppTypography.sectionHeading,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${MaterialLocalizations.of(context).formatMediumDate(recordedAt)} · ${TimeOfDay.fromDateTime(recordedAt).format(context)}',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _ReadingValue(
                label: 'Water in soil',
                value: _value(reading.soilMoisture, '%'),
                icon: Icons.water_drop_rounded,
                colors: AppColors.soilMoistureGradient,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ReadingValue(
                label: 'Soil temperature',
                value: _value(reading.soilTemperature, '°C'),
                icon: Icons.thermostat_rounded,
                colors: AppColors.soilTemperatureGradient,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _ReadingValue(
                label: 'Air temperature',
                value: _value(reading.environmentTemperature, '°C'),
                icon: Icons.wb_sunny_rounded,
                colors: AppColors.airTemperatureGradient,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ReadingValue(
                label: 'Humidity',
                value: _value(reading.humidity, '%'),
                icon: Icons.cloud_rounded,
                colors: AppColors.humidityGradient,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SensorReadingRow extends StatelessWidget {
  const _SensorReadingRow({required this.reading});

  final CropSensorReading reading;

  @override
  Widget build(BuildContext context) {
    final recordedAt = reading.recordedAt.toLocal();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  color: AppColors.primaryGreen, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  MaterialLocalizations.of(context)
                      .formatMediumDate(recordedAt),
                  style: AppTypography.small.copyWith(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                TimeOfDay.fromDateTime(recordedAt).format(context),
                style: AppTypography.caption,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _HistoryValue(
                    label: 'Water in soil',
                    value: _value(reading.soilMoisture, '%')),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _HistoryValue(
                    label: 'Soil temperature',
                    value: _value(reading.soilTemperature, '°C')),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _HistoryValue(
                    label: 'Air temperature',
                    value: _value(reading.environmentTemperature, '°C')),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _HistoryValue(
                    label: 'Humidity', value: _value(reading.humidity, '%')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryValue extends StatelessWidget {
  const _HistoryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.small.copyWith(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}

class _ReadingValue extends StatelessWidget {
  const _ReadingValue({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
  });

  final String label;
  final String value;
  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.smd,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: Colors.white.withValues(alpha: .86),
              ),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.numericValue.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _SensorHistoryMessage extends StatelessWidget {
  const _SensorHistoryMessage({
    required this.icon,
    required this.message,
    this.action,
  });

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
              Icon(icon, color: AppColors.primaryGreen, size: 40),
              const SizedBox(height: AppSpacing.sm),
              Text(message,
                  textAlign: TextAlign.center, style: AppTypography.body),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.md),
                action!,
              ],
            ],
          ),
        ),
      );
}

String _value(double? value, String unit) =>
    value == null ? 'Unavailable' : '${value.toStringAsFixed(1)}$unit';

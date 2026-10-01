import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/soil_moisture_reference_label.dart';
import '../../../../shared/utils/sensor_reading_age_label.dart';
import '../../../../shared/widgets/history_pagination.dart';
import '../../data/models/crop_model.dart';
import '../../providers/crop_providers.dart';

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
        loading: () => const Center(child: CircularProgressIndicator()),
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
                  AppSpacing.sm,
                ),
                child: Text(
                  items.length == 100
                      ? 'Showing the latest 100 readings'
                      : '${items.length} recorded reading${items.length == 1 ? '' : 's'}',
                  style: AppTypography.small,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        itemCount: visibleReadings.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) =>
                            _SensorReadingCard(reading: visibleReadings[index]),
                      ),
                    ),
                    if (items.length > _pageSize)
                      HistoryPagination(
                        pageIndex: pageIndex,
                        totalRecords: items.length,
                        pageSize: _pageSize,
                        onPageChanged: (page) =>
                            setState(() => _pageIndex = page),
                      ),
                  ],
                ),
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

class _SensorReadingCard extends StatelessWidget {
  const _SensorReadingCard({required this.reading});

  final CropSensorReading reading;

  @override
  Widget build(BuildContext context) {
    final recordedAt = reading.recordedAt.toLocal();
    final fresh = reading.isFresh;
    final verified = reading.provenanceStatus == 'verified_hardware';
    final statusColor = fresh && verified
        ? AppColors.success
        : fresh
            ? AppColors.warning
            : AppColors.mutedText;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.inactiveBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sensors_outlined,
                  color: AppColors.primaryGreen, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  MaterialLocalizations.of(context)
                      .formatMediumDate(recordedAt),
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  sensorReadingAgeLabel(recordedAt),
                  style: AppTypography.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${TimeOfDay.fromDateTime(recordedAt).format(context)} · ${reading.source} · ${_provenanceLabel(reading.provenanceStatus)}',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _ReadingValue(
                  label: 'Soil moisture',
                  value: _value(reading.soilMoisture, '%'),
                  detail: reading.soilMoistureCalibrated == true
                      ? soilMoistureReferenceLabel(reading.soilMoisture)
                      : null),
              _ReadingValue(
                  label: 'Raw soil (ADC)',
                  value: reading.soilRaw?.toString() ?? 'Unavailable'),
              _ReadingValue(
                  label: 'Soil temperature',
                  value: _value(reading.soilTemperature, '°C')),
              _ReadingValue(
                  label: 'Air temperature',
                  value: _value(reading.environmentTemperature, '°C')),
              _ReadingValue(
                  label: 'Humidity', value: _value(reading.humidity, '%')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadingValue extends StatelessWidget {
  const _ReadingValue({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.caption),
            Text(value, style: AppTypography.numericSmall),
            if (detail != null)
              Text(
                detail!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText,
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

String _provenanceLabel(String value) => switch (value) {
      'verified_hardware' => 'Verified hardware',
      'demo' => 'Demo',
      'simulated' => 'Simulated',
      _ => 'Unverified source',
    };

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/crop_model.dart';
import '../../providers/crop_providers.dart';

class CropWeatherCard extends ConsumerWidget {
  const CropWeatherCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(cropWeatherProvider);

    return weather.when(
      loading: () => const _WeatherSurface(
        child: SizedBox(
          height: 92,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (error, stackTrace) => _WeatherSurface(
        child: _WeatherUnavailable(
          message: 'Weather forecast is unavailable.',
          onRetry: () => ref.invalidate(cropWeatherProvider),
        ),
      ),
      data: (snapshot) => _WeatherContent(
        snapshot: snapshot,
        onRetry: () => ref.invalidate(cropWeatherProvider),
      ),
    );
  }
}

class _WeatherContent extends StatelessWidget {
  const _WeatherContent({required this.snapshot, required this.onRetry});

  final CropWeatherSnapshot snapshot;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final available =
        snapshot.currentCondition.toLowerCase() != 'weather unavailable' ||
            snapshot.temperatureC != null ||
            snapshot.rainChancePercent != null;
    final isStale = snapshot.fetchedAt != null &&
        DateTime.now().difference(snapshot.fetchedAt!) >
            const Duration(hours: 12);
    final weatherColor = _weatherColor(snapshot.currentCondition);

    return _WeatherSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: weatherColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  _weatherIcon(snapshot.currentCondition),
                  color: weatherColor,
                  size: 23,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Farm weather', style: AppTypography.sectionHeading),
                    const SizedBox(height: 2),
                    Text(
                      available
                          ? snapshot.currentCondition
                          : 'Forecast unavailable',
                      style: AppTypography.small.copyWith(
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh weather forecast',
                visualDensity: VisualDensity.compact,
                onPressed: onRetry,
                icon: Icon(Icons.refresh_rounded,
                    color: AppColors.secondaryText, size: 20),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _WeatherMetric(
                  icon: Icons.thermostat_rounded,
                  label: 'Temperature',
                  value: snapshot.temperatureC == null
                      ? 'Unavailable'
                      : '${snapshot.temperatureC!.round()}°C',
                  color: const Color(0xFFB65B24),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _WeatherMetric(
                  icon: Icons.water_drop_outlined,
                  label: 'Rain chance',
                  value: snapshot.rainChancePercent == null
                      ? 'Unavailable'
                      : '${snapshot.rainChancePercent!.round()}%',
                  color: const Color(0xFF2672A8),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.grain_rounded,
                  size: 16, color: AppColors.secondaryText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  snapshot.nextRainAt == null
                      ? available
                          ? 'No rain window expected in the next 24 hours'
                          : snapshot.unavailableMessage ??
                              'WeatherAPI forecast is unavailable.'
                      : 'Next rain window · ${DateFormat('EEE, h:mm a').format(snapshot.nextRainAt!.toLocal())}',
                  style: AppTypography.caption,
                ),
              ),
            ],
          ),
          if (snapshot.fetchedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              '${isStale ? 'Last update' : 'Updated'} ${DateFormat('MMM d, h:mm a').format(snapshot.fetchedAt!.toLocal())}${isStale ? ' · may be outdated' : ''} · ${snapshot.source}',
              style: AppTypography.caption.copyWith(
                color: isStale ? AppColors.warning : AppColors.mutedText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.inactiveBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.caption),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.numericValue.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _WeatherUnavailable extends StatelessWidget {
  const _WeatherUnavailable({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(message, style: AppTypography.small)),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ],
      );
}

class _WeatherSurface extends StatelessWidget {
  const _WeatherSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.inactiveBorder),
        ),
        child: child,
      );
}

IconData _weatherIcon(String condition) {
  final value = condition.toLowerCase();
  if (value.contains('thunder')) return Icons.thunderstorm_rounded;
  if (value.contains('rain') || value.contains('drizzle')) {
    return Icons.cloudy_snowing;
  }
  if (value.contains('clear') || value.contains('sun')) {
    return Icons.wb_sunny_rounded;
  }
  if (value.contains('fog')) return Icons.foggy;
  return Icons.cloud_rounded;
}

Color _weatherColor(String condition) {
  final value = condition.toLowerCase();
  if (value.contains('thunder') || value.contains('rain')) {
    return const Color(0xFF2672A8);
  }
  if (value.contains('clear') || value.contains('sun')) {
    return const Color(0xFFC17A15);
  }
  return AppColors.primaryGreen;
}

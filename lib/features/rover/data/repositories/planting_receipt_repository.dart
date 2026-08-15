import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/planting_session_model.dart';
import '../models/rover_command_model.dart';

class PlantingReceiptRepository {
  PlantingReceiptRepository(this._client);

  static const _storageKey = 'pending_rover_planting_receipts_v1';
  static const _calibrationKey = 'pending_rover_calibration_v1';
  final SupabaseClient _client;

  Future<List<PendingPlantingReceipt>> loadPending() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getStringList(_storageKey) ?? const [];
    return raw
        .map((value) => PendingPlantingReceipt.fromJson(
            jsonDecode(value) as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(PendingPlantingReceipt receipt) async {
    final pending = await loadPending();
    final existing = pending.indexWhere(
        (item) => item.config.sessionId == receipt.config.sessionId);
    if (existing >= 0) {
      pending[existing] = receipt;
    } else {
      pending.add(receipt);
    }
    await _persist(pending);
  }

  Future<void> saveCalibration(RoverCalibrationModel calibration) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        _calibrationKey, jsonEncode(calibration.toJson()));
  }

  Future<int> synchronize() async {
    if (_client.auth.currentUser == null) return 0;
    await _synchronizeCalibration();
    final pending = await loadPending();
    final retained = <PendingPlantingReceipt>[];
    var synced = 0;
    for (final receipt in pending) {
      try {
        final completed = receipt.status.completedDrops;
        final terminalStatus = completed == 0
            ? 'Failed'
            : completed >= receipt.config.targetDrops
                ? 'Completed'
                : 'Partial';
        await _client.rpc('record_rover_planting_session', params: {
          'p_client_session_id': receipt.config.sessionId,
          'p_rover_id': 'SeedRover-01',
          'p_crop_profile_key': receipt.config.seed.payloadValue,
          'p_field_label': receipt.config.fieldLabel,
          'p_target_drop_cycles': receipt.config.targetDrops,
          'p_completed_drop_cycles': completed,
          'p_measured_distance_cm': receipt.status.distanceCm,
          'p_row_spacing_cm': receipt.config.rowSpacingCm,
          'p_status': terminalStatus,
          'p_started_at': receipt.startedAt.toUtc().toIso8601String(),
          'p_completed_at': receipt.completedAt.toUtc().toIso8601String(),
          'p_soil_raw': receipt.status.soilRaw,
          'p_soil_moisture_percent': receipt.status.soilPercent,
          'p_environmental_temperature': receipt.status.temperatureC,
          'p_seed_load_raw': receipt.status.seedLoadRaw,
          'p_firmware_version': receipt.status.firmwareVersion,
          'p_failure_code': receipt.status.failureCode,
          'p_sync_payload': receipt.toJson(),
        });
        final existingCalibration = await _client
            .from('rover_calibrations')
            .select('seed_gate_profiles')
            .eq('rover_id', 'SeedRover-01')
            .maybeSingle();
        final profiles = Map<String, dynamic>.from(
          existingCalibration?['seed_gate_profiles'] as Map? ?? const {},
        );
        profiles[receipt.config.seed.payloadValue] = {
          'gate_open_ms': receipt.config.gateOpenMs,
          'estimated_min': receipt.config.estimatedSeedsPerDropMin,
          'estimated_max': receipt.config.estimatedSeedsPerDropMax,
        };
        await _client.from('rover_calibrations').upsert({
          'rover_id': 'SeedRover-01',
          'seed_gate_profiles': profiles,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        synced++;
      } catch (_) {
        retained.add(receipt);
      }
    }
    await _persist(retained);
    return synced;
  }

  Future<void> _synchronizeCalibration() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_calibrationKey);
    if (raw == null) return;
    final calibration = RoverCalibrationModel.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    try {
      await _client.from('rover_calibrations').upsert({
        'rover_id': 'SeedRover-01',
        'left_encoder_ticks_per_meter': calibration.leftTicksPerMeter,
        'right_encoder_ticks_per_meter': calibration.rightTicksPerMeter,
        'soil_dry_raw': calibration.soilDryRaw,
        'soil_wet_raw': calibration.soilWetRaw,
        'rake_to_gate_offset_cm': calibration.rakeToGateCm,
        'calibrated_by': user.id,
        'calibrated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      await preferences.remove(_calibrationKey);
    } catch (_) {
      // Keep calibration locally until the phone has internet again.
    }
  }

  Future<void> _persist(List<PendingPlantingReceipt> receipts) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _storageKey,
      receipts.map((receipt) => jsonEncode(receipt.toJson())).toList(),
    );
  }
}

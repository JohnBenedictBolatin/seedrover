import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/planting_session_model.dart';
import '../models/rover_command_model.dart';

class PlantingReceiptRepository {
  PlantingReceiptRepository(this._client);

  static const _storageKey = 'pending_rover_planting_receipts_v1';
  static const _historyKey = 'rover_planting_history_v1';
  static const _calibrationKey = 'pending_rover_calibration_v1';
  final SupabaseClient _client;
  Future<void> _writeQueue = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() write) {
    final result = _writeQueue.then((_) => write());
    _writeQueue =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<List<PendingPlantingReceipt>> _loadAll() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getStringList(_storageKey) ?? const [];
    return raw
        .map((value) => PendingPlantingReceipt.fromJson(
            jsonDecode(value) as Map<String, dynamic>))
        .toList();
  }

  Future<List<PendingPlantingReceipt>> loadPending() async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) return const [];
    return (await _loadAll())
        .where((receipt) => receipt.ownerId == ownerId)
        .toList();
  }

  Future<List<PendingPlantingReceipt>> loadRecords() async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) return const [];
    final preferences = await SharedPreferences.getInstance();
    final archived = preferences.getStringList(_historyKey) ?? const [];
    final history = archived.map((value) => PendingPlantingReceipt.fromJson(
          jsonDecode(value) as Map<String, dynamic>,
        ));
    final pending = await loadPending();
    return [
      ...pending,
      ...history.where((receipt) => receipt.ownerId == ownerId)
    ]..sort((left, right) => right.completedAt.compareTo(left.completedAt));
  }

  Future<PendingPlantingReceipt?> findPending(String sessionId) async {
    for (final receipt in await loadPending()) {
      if (receipt.config.sessionId == sessionId) return receipt;
    }
    return null;
  }

  Future<PendingPlantingReceipt?> findRecord(String sessionId) async {
    for (final receipt in await loadRecords()) {
      if (receipt.config.sessionId == sessionId) return receipt;
    }
    return null;
  }

  Future<void> saveDraft(PlantingRowConfig config) async {
    if (_client.auth.currentUser == null) {
      throw StateError('Sign in before starting a planting run.');
    }
    final now = DateTime.now();
    await save(PendingPlantingReceipt(
      config: config,
      status: PlantingOperationStatus(
        state: 'STARTING',
        sessionId: config.sessionId,
        cropProfile: config.seed.payloadValue,
        fieldLabel: config.fieldLabel,
        targetDrops: config.targetDrops,
        completedDrops: 0,
        distanceCm: 0,
        soilRaw: null,
        soilPercent: null,
        soilTemperatureC: null,
        airTemperatureC: null,
        humidityPercent: null,
        frontDistanceCm: null,
        rearDistanceCm: null,
        firmwareVersion: '',
        distanceIsEstimated: true,
        movementTracking: 'unknown',
      ),
      startedAt: now,
      completedAt: now,
    ));
  }

  Future<void> discardUnstartedDraft(String sessionId) async {
    return _serialize(() async {
      final ownerId = _client.auth.currentUser?.id;
      if (ownerId == null) return;
      final all = await _loadAll();
      all.removeWhere((receipt) =>
          receipt.ownerId == ownerId &&
          receipt.config.sessionId == sessionId &&
          receipt.status.state == 'STARTING');
      await _persistAll(all);
    });
  }

  Future<void> save(PendingPlantingReceipt receipt) async {
    return _serialize(() async {
      final ownerId = _client.auth.currentUser?.id;
      var ownedReceipt = receipt.copyWith(ownerId: ownerId);
      final all = await _loadAll();
      final existing = all.indexWhere((item) =>
          item.ownerId == ownerId &&
          item.config.sessionId == receipt.config.sessionId);
      if (existing >= 0) {
        final previous = all[existing];
        ownedReceipt = ownedReceipt.copyWith(
          confirmationOutcome: previous.confirmationOutcome,
          remoteLogId: previous.remoteLogId,
          confirmationSynced: previous.confirmationSynced,
          soilCapturedAt:
              ownedReceipt.soilCapturedAt ?? previous.soilCapturedAt,
        );
        all[existing] = ownedReceipt;
      } else {
        all.add(ownedReceipt);
      }
      await _persistAll(all);
    });
  }

  Future<void> confirm(String sessionId, {required String outcome}) async {
    return _serialize(() async {
      final ownerId = _client.auth.currentUser?.id;
      if (ownerId == null) {
        throw StateError('Sign in again before saving the planting result.');
      }
      if (!const {'row_planted', 'some_planted', 'none_planted'}
          .contains(outcome)) {
        throw ArgumentError.value(outcome, 'outcome', 'Unknown result');
      }
      final all = await _loadAll();
      final index = all.indexWhere((receipt) =>
          receipt.ownerId == ownerId && receipt.config.sessionId == sessionId);
      if (index < 0) {
        throw StateError(
          'This planting run is not saved on this phone. The result was not confirmed.',
        );
      }
      if (!all[index].status.isTerminal) {
        throw StateError(
          'The rover has not finished this planting run yet. The result was not confirmed.',
        );
      }
      all[index] = all[index].copyWith(
        confirmationOutcome: outcome,
      );
      await _persistAll(all);
    });
  }

  Future<void> saveCalibration(RoverCalibrationModel calibration) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        _calibrationKey, jsonEncode(calibration.toJson()));
  }

  Future<RoverCalibrationModel?> loadPendingCalibration() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_calibrationKey);
    if (raw == null) return null;
    try {
      return RoverCalibrationModel.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<PlantingSyncResult> synchronize() async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) return const PlantingSyncResult();
    await _synchronizeCalibration();
    final pending = await loadPending();
    final retained = <PendingPlantingReceipt>[];
    final newlyArchived = <PendingPlantingReceipt>[];
    var synced = 0;
    var failed = 0;
    String? lastCropId;
    String? lastSessionId;
    String? lastConfirmedSessionId;
    String? lastError;
    for (final receipt in pending) {
      if (!receipt.status.isTerminal) {
        retained.add(receipt);
        continue;
      }
      try {
        final completed = receipt.status.completedDrops;
        final terminalStatus = completed >= receipt.config.targetDrops
            ? 'Completed'
            : receipt.status.state == 'CANCELLED'
                ? 'Cancelled'
                : completed > 0
                    ? 'Partial'
                    : 'Failed';
        final response = await _client.rpc('sync_rover_planting_run', params: {
          'p_run': {
            'session_id': receipt.config.sessionId,
            'rover_id': 'SeedRover-01',
            'crop_profile_key': receipt.config.seed.payloadValue,
            'field_label': receipt.config.fieldLabel,
            'target_drop_cycles': receipt.config.targetDrops,
            'completed_drop_cycles': completed,
            'measured_distance_cm': receipt.status.distanceCm,
            'row_spacing_cm': receipt.config.rowSpacingCm,
            'planting_status': terminalStatus,
            'started_at': receipt.startedAt.toUtc().toIso8601String(),
            'completed_at': receipt.completedAt.toUtc().toIso8601String(),
            'soil_raw': receipt.status.soilRaw,
            'soil_moisture_percent': receipt.status.soilPercent,
            'soil_temperature_c': receipt.status.soilTemperatureC,
            'air_temperature_c': receipt.status.airTemperatureC,
            'humidity_percent': receipt.status.humidityPercent,
            'soil_captured_at_ms': receipt.status.soilCapturedAtMs,
            'soil_captured_at':
                receipt.soilCapturedAt?.toUtc().toIso8601String(),
            'firmware_version': receipt.status.firmwareVersion,
            'failure_code': receipt.status.failureCode,
            'confirmation_outcome': receipt.confirmationOutcome,
            'sync_payload': receipt.toJson(),
          },
        });
        final result = Map<String, dynamic>.from(response as Map);
        final cropId = result['crop_id']?.toString();
        if (cropId != null && cropId.isNotEmpty) {
          lastCropId = cropId;
        }
        lastSessionId = receipt.config.sessionId;
        if (receipt.isConfirmed) {
          lastConfirmedSessionId = receipt.config.sessionId;
        }
        synced++;
        if (!receipt.isConfirmed) {
          retained.add(receipt.copyWith(
            remoteLogId: result['planting_log_id']?.toString(),
            clearSyncError: true,
          ));
        } else {
          newlyArchived.add(receipt.copyWith(
            remoteLogId: result['planting_log_id']?.toString(),
            confirmationSynced: true,
            clearSyncError: true,
          ));
        }
      } catch (error) {
        failed++;
        final message = _syncErrorMessage(error);
        lastError ??= message;
        retained.add(receipt.copyWith(syncError: message));
      }
    }
    await _persistAccount(retained, ownerId, processedReceipts: pending);
    if (newlyArchived.isNotEmpty) {
      await _appendHistory(newlyArchived, ownerId);
    }
    return PlantingSyncResult(
      synchronizedCount: synced,
      failedCount: failed,
      lastCropId: lastCropId,
      lastSessionId: lastSessionId,
      lastConfirmedSessionId: lastConfirmedSessionId,
      lastError: lastError,
    );
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
        'seconds_per_meter': calibration.secondsPerMeter,
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

  Future<void> _persistAccount(
    List<PendingPlantingReceipt> accountReceipts,
    String ownerId, {
    required List<PendingPlantingReceipt> processedReceipts,
  }) {
    return _serialize(() async {
      final all = await _loadAll();
      final processedById = {
        for (final receipt in processedReceipts)
          receipt.config.sessionId: receipt,
      };
      final processedIds = processedById.keys.toSet();
      final updatedWhileSyncing = all.where((item) {
        if (item.ownerId != ownerId ||
            !processedIds.contains(item.config.sessionId)) {
          return false;
        }
        final snapshot = processedById[item.config.sessionId];
        // A local rover update or operator confirmation may arrive while an
        // older snapshot is being uploaded. Preserve that newer local record;
        // the next sync can safely retry it using the idempotent session ID.
        return snapshot != null &&
            jsonEncode(item.toJson()) != jsonEncode(snapshot.toJson());
      });
      final keptNew = all.where((item) =>
          item.ownerId != ownerId ||
          !processedIds.contains(item.config.sessionId));
      final merged = <PendingPlantingReceipt>[
        ...keptNew,
        ...updatedWhileSyncing,
      ];
      for (final receipt in accountReceipts) {
        if (!merged.any((item) =>
            item.ownerId == ownerId &&
            item.config.sessionId == receipt.config.sessionId)) {
          merged.add(receipt);
        }
      }
      await _persistAll(merged);
    });
  }

  Future<void> _persistAll(List<PendingPlantingReceipt> receipts) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _storageKey,
      receipts.map((receipt) => jsonEncode(receipt.toJson())).toList(),
    );
  }

  Future<void> _appendHistory(
    List<PendingPlantingReceipt> completed,
    String ownerId,
  ) {
    return _serialize(() async {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getStringList(_historyKey) ?? const [];
      final all = raw
          .map((value) => PendingPlantingReceipt.fromJson(
                jsonDecode(value) as Map<String, dynamic>,
              ))
          .toList();
      for (final receipt in completed) {
        final index = all.indexWhere((item) =>
            item.ownerId == ownerId &&
            item.config.sessionId == receipt.config.sessionId);
        if (index >= 0) {
          all[index] = receipt;
        } else {
          all.add(receipt);
        }
      }
      await preferences.setStringList(
        _historyKey,
        all.map((receipt) => jsonEncode(receipt.toJson())).toList(),
      );
    });
  }

  String _syncErrorMessage(Object error) {
    final raw =
        error.toString().replaceFirst(RegExp(r'^Exception: '), '').trim();
    final lower = raw.toLowerCase();
    if (lower.contains('permission required') ||
        lower.contains('permission denied') ||
        lower.contains('not authorized')) {
      return 'Your account cannot sync planting runs. Ask an administrator to check rover planting permission.';
    }
    if (lower.contains('unknown crop profile')) {
      return 'The seed profile for this older run is no longer active. Ask an administrator to review the crop profile.';
    }
    if (lower.contains('already confirmed differently')) {
      return 'The server has a different planting confirmation for this run. It needs reconciliation before retrying.';
    }
    return raw.length > 180 ? '${raw.substring(0, 177)}…' : raw;
  }
}

class PlantingSyncResult {
  const PlantingSyncResult({
    this.synchronizedCount = 0,
    this.failedCount = 0,
    this.lastCropId,
    this.lastSessionId,
    this.lastConfirmedSessionId,
    this.lastError,
  });
  final int synchronizedCount;
  final int failedCount;
  final String? lastCropId;
  final String? lastSessionId;
  final String? lastConfirmedSessionId;
  final String? lastError;
}

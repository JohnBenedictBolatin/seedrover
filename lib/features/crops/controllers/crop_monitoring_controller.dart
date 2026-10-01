import '../../../shared/models/action_outcome.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/crop_model.dart';
import '../data/repositories/crop_repository.dart';
import 'crop_monitoring_state.dart';

class CropMonitoringController extends StateNotifier<CropMonitoringState> {
  CropMonitoringController(this._repository)
      : super(CropMonitoringState.initial()) {
    loadCrops();
    _draftRetryTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        await retryPendingDrafts();
      } catch (_) {/* Keep unsent drafts for the next attempt. */}
    });
    _subscription = _repository.watchCrops().listen(
      (crops) => _setCrops(crops, successMessage: null, isLoading: false),
      onError: (_) {
        state = state.copyWith(
          isLoading: state.crops.isEmpty ? state.isLoading : false,
          errorMessage: state.crops.isEmpty
              ? 'Crop records are temporarily unavailable.'
              : state.errorMessage,
        );
      },
    );
  }

  final CropRepository _repository;
  StreamSubscription<List<CropModel>>? _subscription;
  Timer? _draftRetryTimer;
  int _loadGeneration = 0;

  Future<List<Map<String, dynamic>>> careDrafts() =>
      _repository.getCareDrafts();

  Future<bool> retryDraft(String submissionId) async {
    final synced = await _repository.retryCareDraft(submissionId);
    await loadCrops();
    return synced;
  }

  Future<void> loadCrops() async {
    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final crops = await _repository.getCrops();
      if (!mounted || generation != _loadGeneration) return;
      _setCrops(crops, successMessage: null, isLoading: false);
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(
          error,
          fallback: 'Unable to load crop monitoring data.',
        ),
      );
    }
  }

  Future<void> refreshCrops() async {
    state = state.copyWith(isLoading: true, successMessage: null);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await loadCrops();
  }

  void updateSearch(String query) {
    _updateFilters(searchQuery: query);
  }

  void updateFilter(CropFilterType filter) {
    _updateFilters(selectedFilter: filter);
  }

  void updateCropName(String? cropName) {
    _updateFilters(selectedCropName: cropName);
  }

  void updatePlantingDate(DateTime? date) {
    _updateFilters(selectedPlantingDate: date);
  }

  void updateHarvestDate(DateTime? date) {
    _updateFilters(selectedHarvestDate: date);
  }

  void updateGrowthStage(CropGrowthStage? stage) {
    _updateFilters(selectedGrowthStage: stage);
  }

  void updateSort(CropSortType sortType) {
    _updateFilters(selectedSort: sortType);
  }

  CropModel? cropById(String cropId) {
    for (final crop in state.crops) {
      if (crop.id == cropId) {
        return crop;
      }
    }

    return null;
  }

  Future<bool> waterCrop({
    required String cropId,
    required String notes,
    required DateTime date,
    required double quantity,
    required String unit,
    String? taskId,
  }) async {
    if (quantity <= 0 || unit.trim().isEmpty) {
      state = state.copyWith(
          errorMessage: 'Enter a quantity greater than zero and its unit.');
      return false;
    }
    return _addMaintenance(
      cropId: cropId,
      activity: CropMaintenanceActivity.watered,
      date: date,
      notes: notes.trim(),
      quantity: quantity,
      unit: unit,
      successMessage: 'Watering activity recorded.',
      taskId: taskId,
    );
  }

  Future<bool> fertilizeCrop({
    required String cropId,
    required String fertilizerType,
    required String notes,
    required DateTime date,
    required double quantity,
    required String unit,
    String? taskId,
  }) async {
    if (quantity <= 0 || unit.trim().isEmpty || fertilizerType.trim().isEmpty) {
      state = state.copyWith(
          errorMessage:
              'Enter the fertilizer, a quantity greater than zero, and its unit.');
      return false;
    }
    return _addMaintenance(
      cropId: cropId,
      activity: CropMaintenanceActivity.fertilized,
      date: date,
      notes: notes.trim(),
      quantity: quantity,
      unit: unit,
      material: fertilizerType,
      taskId: taskId,
      successMessage: 'Fertilizer activity recorded.',
    );
  }

  Future<bool> harvestCrop({
    required String cropId,
    required double quantity,
    required String unit,
    required String notes,
    String? submissionId,
    String? inventoryName,
  }) async {
    if (quantity <= 0 || unit.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Enter a harvested quantity greater than zero.',
      );
      return false;
    }
    final now = DateTime.now();

    return _addMaintenance(
      cropId: cropId,
      activity: CropMaintenanceActivity.harvested,
      date: now,
      notes: notes.trim(),
      quantity: quantity,
      unit: 'kg',
      submissionId: submissionId,
      successMessage:
          '$quantity kg added to ${inventoryName ?? 'inventory'}. Batch closed.',
    );
  }

  Future<bool> markCropNotHarvested({
    required String cropId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Add a reason the crop could not be harvested.',
      );
      return false;
    }

    return _addMaintenance(
      cropId: cropId,
      activity: CropMaintenanceActivity.notHarvested,
      date: DateTime.now(),
      notes: reason.trim(),
      successMessage: 'Crop marked as not harvested.',
    );
  }

  Future<bool> recordCareEntry({
    required String cropId,
    required CropMaintenanceActivity activity,
    required DateTime date,
    String? notes,
    double? quantity,
    String? unit,
    String? material,
    String? observedStage,
    String? taskId,
    List<String> photos = const [],
    String? submissionId,
  }) =>
      _addMaintenance(
          cropId: cropId,
          activity: activity,
          date: date,
          notes: notes ?? '',
          quantity: quantity,
          unit: unit,
          material: material,
          observedStage: observedStage,
          taskId: taskId,
          photos: photos,
          submissionId: submissionId,
          successMessage: 'Crop activity recorded.');

  Future<String> recordRoverSensorCheck({
    required String cropId,
    required Map<String, dynamic> readings,
  }) async {
    final crop = cropById(cropId);
    if (crop == null || crop.isCompleted) {
      state = state.copyWith(
        errorMessage: 'Choose a crop that is still growing.',
      );
      return 'Choose a crop that is still growing.';
    }
    try {
      final synced = await _repository.recordSensorCheck(
        cropId: cropId,
        readings: readings,
      );
      if (synced) await loadCrops();
      final message = synced
          ? 'Sensor reading saved to crop history.'
          : 'Sensor reading saved on this device. It will sync when internet returns.';
      state = state.copyWith(
        successMessage: message,
      );
      return message;
    } catch (error) {
      state = state.copyWith(
        errorMessage: _friendlyError(
          error,
          fallback: 'Unable to save this sensor reading.',
        ),
      );
      return _friendlyError(
        error,
        fallback: 'Unable to save this sensor reading.',
      );
    }
  }

  String newSubmissionId() => _repository.newSubmissionId();

  Future<Map<String, dynamic>> getHarvestDestination(String cropId) =>
      _repository.getHarvestDestination(cropId);

  Future<void> retryPendingDrafts() async {
    await _repository.retryPendingCareDrafts();
    await _repository.retryPendingSensorChecks();
    await loadCrops();
  }

  Future<int> pendingSensorCheckCount() =>
      _repository.pendingSensorCheckCount();

  Future<List<Map<String, dynamic>>> pendingSensorChecks() =>
      _repository.pendingSensorChecks();

  Future<int> retryPendingSensorChecks() async {
    final synced = await _repository.retryPendingSensorChecks();
    if (synced > 0) await loadCrops();
    return synced;
  }

  Future<bool> updateCrop(CropModel crop) async {
    try {
      final updatedCrop = await _repository.updateCrop(crop);
      _replaceCrop(updatedCrop, successMessage: 'Crop information updated.');
      return true;
    } catch (error) {
      state = state.copyWith(
        errorMessage: _friendlyError(error, fallback: 'Unable to update crop.'),
      );
      return false;
    }
  }

  Future<bool> deleteCrop(String cropId) async {
    try {
      await _repository.deleteCrop(cropId);
      final crops = state.crops.where((crop) => crop.id != cropId).toList();
      _setCrops(crops, successMessage: 'Crop deleted.', isLoading: false);
      return true;
    } catch (error) {
      state = state.copyWith(
        errorMessage: _friendlyError(error, fallback: 'Unable to delete crop.'),
      );
      return false;
    }
  }

  void clearFilters() {
    final filteredCrops = _applyFilters(
      crops: state.crops,
      searchQuery: '',
      selectedFilter: CropFilterType.all,
      selectedCropName: null,
      selectedPlantingDate: null,
      selectedHarvestDate: null,
      selectedGrowthStage: null,
      selectedSort: state.selectedSort,
    );

    state = state.copyWith(
      searchQuery: '',
      selectedFilter: CropFilterType.all,
      selectedCropName: null,
      selectedPlantingDate: null,
      selectedHarvestDate: null,
      selectedGrowthStage: null,
      filteredCrops: filteredCrops,
      selectedCropId: filteredCrops.isEmpty ? null : filteredCrops.first.id,
      successMessage: null,
    );
  }

  void clearSuccessMessage() {
    state = state.copyWith(successMessage: null);
  }

  void clearErrorMessage() {
    state = state.copyWith(errorMessage: null);
  }

  void _updateFilters({
    String? searchQuery,
    CropFilterType? selectedFilter,
    Object? selectedCropName = _noCropNameChange,
    Object? selectedPlantingDate = _noPlantingDateChange,
    Object? selectedHarvestDate = _noHarvestDateChange,
    Object? selectedGrowthStage = _noStageChange,
    CropSortType? selectedSort,
  }) {
    final nextSearchQuery = searchQuery ?? state.searchQuery;
    final nextFilter = selectedFilter ?? state.selectedFilter;
    final nextCropName = selectedCropName == _noCropNameChange
        ? state.selectedCropName
        : selectedCropName as String?;
    final nextPlantingDate = selectedPlantingDate == _noPlantingDateChange
        ? state.selectedPlantingDate
        : selectedPlantingDate as DateTime?;
    final nextHarvestDate = selectedHarvestDate == _noHarvestDateChange
        ? state.selectedHarvestDate
        : selectedHarvestDate as DateTime?;
    final nextGrowthStage = selectedGrowthStage == _noStageChange
        ? state.selectedGrowthStage
        : selectedGrowthStage as CropGrowthStage?;
    final nextSort = selectedSort ?? state.selectedSort;
    final filteredCrops = _applyFilters(
      crops: state.crops,
      searchQuery: nextSearchQuery,
      selectedFilter: nextFilter,
      selectedCropName: nextCropName,
      selectedPlantingDate: nextPlantingDate,
      selectedHarvestDate: nextHarvestDate,
      selectedGrowthStage: nextGrowthStage,
      selectedSort: nextSort,
    );

    state = state.copyWith(
      searchQuery: nextSearchQuery,
      selectedFilter: nextFilter,
      selectedCropName: nextCropName,
      selectedPlantingDate: nextPlantingDate,
      selectedHarvestDate: nextHarvestDate,
      selectedGrowthStage: nextGrowthStage,
      selectedSort: nextSort,
      filteredCrops: filteredCrops,
      selectedCropId: filteredCrops.isEmpty ? null : filteredCrops.first.id,
      successMessage: null,
    );
  }

  List<CropModel> _applyFilters({
    required List<CropModel> crops,
    required String searchQuery,
    required CropFilterType selectedFilter,
    required String? selectedCropName,
    required DateTime? selectedPlantingDate,
    required DateTime? selectedHarvestDate,
    required CropGrowthStage? selectedGrowthStage,
    required CropSortType selectedSort,
  }) {
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final filtered = crops.where((crop) {
      final matchesSearch = normalizedQuery.isEmpty ||
          crop.name.toLowerCase().contains(normalizedQuery) ||
          crop.variety.toLowerCase().contains(normalizedQuery) ||
          crop.location.toLowerCase().contains(normalizedQuery) ||
          crop.trackingCode.toLowerCase().contains(normalizedQuery) ||
          crop.id.toLowerCase().contains(normalizedQuery);
      final matchesCropName =
          selectedCropName == null || crop.name == selectedCropName;
      final matchesPlantingDate = selectedPlantingDate == null ||
          _sameDate(crop.plantingDate, selectedPlantingDate);
      final matchesHarvestDate = selectedHarvestDate == null ||
          (crop.estimatedHarvest != null &&
              _sameDate(crop.estimatedHarvest!, selectedHarvestDate));
      final matchesFilter = switch (selectedFilter) {
        CropFilterType.all => !crop.isCompleted,
        CropFilterType.active => crop.status == CropStatus.active,
        CropFilterType.needsAttention =>
          crop.status == CropStatus.needsAttention,
        CropFilterType.readyForHarvest =>
          crop.status == CropStatus.readyForHarvest,
        CropFilterType.harvested => crop.isCompleted,
      };
      final matchesGrowthStage = selectedGrowthStage == null ||
          crop.growthStage == selectedGrowthStage;

      return matchesSearch &&
          matchesCropName &&
          matchesPlantingDate &&
          matchesHarvestDate &&
          matchesFilter &&
          matchesGrowthStage;
    }).toList();

    filtered.sort((left, right) {
      return switch (selectedSort) {
        CropSortType.newest => right.plantingDate.compareTo(left.plantingDate),
        CropSortType.oldest => left.plantingDate.compareTo(right.plantingDate),
        CropSortType.name => left.name.compareTo(right.name),
        CropSortType.harvestSoon => (left.estimatedHarvest ?? DateTime(9999))
            .compareTo(right.estimatedHarvest ?? DateTime(9999)),
      };
    });

    return filtered;
  }

  ActionOutcome lastEntryOutcome = const ActionOutcome.success();

  Future<bool> _addMaintenance({
    required String cropId,
    required CropMaintenanceActivity activity,
    required DateTime date,
    required String notes,
    required String successMessage,
    String? taskId,
    String? observedStage,
    List<String> photos = const [],
    String? submissionId,
    double? quantity,
    String? unit,
    String? material,
  }) async {
    final crop = cropById(cropId);

    if (crop == null) {
      lastEntryOutcome =
          const ActionOutcome.failure('Crop record is unavailable.');
      return false;
    }

    try {
      final result = await _repository.recordCropEntry(
        cropId: crop.id,
        activity: activity,
        date: date,
        notes: notes,
        quantity: quantity,
        unit: unit,
        material: material,
        observedStage: observedStage,
        taskId: taskId,
        photoFiles: photos,
        submissionId: submissionId,
      );
      lastEntryOutcome = result['status'] == 'Saved on device'
          ? const ActionOutcome(ActionStatus.savedLocally,
              'Saved on this phone. Waiting to sync.')
          : const ActionOutcome.success();
      await loadCrops();
      state = state.copyWith(
        successMessage: result['status'] == 'Saved on device'
            ? 'Saved on device. It will sync when the connection returns.'
            : successMessage,
      );
      return true;
    } catch (error) {
      lastEntryOutcome = ActionOutcome.failure(
          _friendlyError(error, fallback: 'Unable to record crop activity.'));
      state = state.copyWith(
        errorMessage: _friendlyError(
          error,
          fallback: 'Unable to record crop activity.',
        ),
      );
      return false;
    }
  }

  void _replaceCrop(CropModel crop, {required String successMessage}) {
    final crops = [
      for (final item in state.crops)
        if (item.id == crop.id) crop else item,
    ];

    _setCrops(crops, successMessage: successMessage, isLoading: false);
  }

  void _setCrops(
    List<CropModel> crops, {
    required String? successMessage,
    required bool isLoading,
  }) {
    final filteredCrops = _applyFilters(
      crops: crops,
      searchQuery: state.searchQuery,
      selectedFilter: state.selectedFilter,
      selectedCropName: state.selectedCropName,
      selectedPlantingDate: state.selectedPlantingDate,
      selectedHarvestDate: state.selectedHarvestDate,
      selectedGrowthStage: state.selectedGrowthStage,
      selectedSort: state.selectedSort,
    );

    state = state.copyWith(
      crops: crops,
      filteredCrops: filteredCrops,
      selectedCropId: filteredCrops.isEmpty ? null : filteredCrops.first.id,
      successMessage: successMessage,
      errorMessage: null,
      isLoading: isLoading,
    );
  }

  bool _sameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  @override
  void dispose() {
    _draftRetryTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

const _noStageChange = Object();
const _noCropNameChange = Object();
const _noPlantingDateChange = Object();
const _noHarvestDateChange = Object();

String _friendlyError(Object error, {required String fallback}) {
  if (error is PostgrestException) {
    final message = error.message;

    if (message.toLowerCase().contains('growth stage cannot move backward')) {
      return 'This crop is already at a later stage. Choose the current stage or a later one.';
    }

    if (message.contains('schema cache') ||
        message.contains('Could not find the function')) {
      return 'Crop database is not fully upgraded yet. Apply the latest Supabase migration and try again.';
    }

    if (message.toLowerCase().contains('permission') ||
        message.toLowerCase().contains('not allowed')) {
      return 'You do not have permission to perform this crop action.';
    }

  }

  return fallback;
}

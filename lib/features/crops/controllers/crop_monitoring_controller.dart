import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/crop_model.dart';
import '../data/repositories/crop_repository.dart';
import 'crop_monitoring_state.dart';

class CropMonitoringController extends StateNotifier<CropMonitoringState> {
  CropMonitoringController(this._repository)
      : super(CropMonitoringState.initial()) {
    loadCrops();
    _subscription = _repository.watchCrops().listen(
      (crops) => _setCrops(crops, successMessage: null, isLoading: false),
      onError: (_) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: null,
        );
      },
    );
  }

  final CropRepository _repository;
  StreamSubscription<List<CropModel>>? _subscription;

  Future<void> loadCrops() async {
    try {
      final crops = await _repository.getCrops();
      _setCrops(crops, successMessage: null, isLoading: false);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load crop monitoring data.',
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

  Future<void> createCrop(CropModel crop) async {
    try {
      final createdCrop = await _repository.createCrop(crop);
      _setCrops(
        [createdCrop, ...state.crops],
        successMessage: 'Crop created.',
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(errorMessage: 'Unable to create crop.');
    }
  }

  Future<void> waterCrop({
    required String cropId,
    required String notes,
    required DateTime date,
    String? amount,
  }) async {
    final amountText = amount == null || amount.trim().isEmpty
        ? ''
        : ' Amount: ${amount.trim()}.';

    await _addMaintenance(
      cropId: cropId,
      activity: CropMaintenanceActivity.watered,
      date: date,
      notes: '$notes$amountText'.trim(),
      successMessage: 'Watering activity recorded.',
      status: CropStatus.healthy,
      lastWateredAt: date,
    );
  }

  Future<void> fertilizeCrop({
    required String cropId,
    required String fertilizerType,
    required String notes,
    required DateTime date,
    String? quantity,
  }) async {
    final quantityText = quantity == null || quantity.trim().isEmpty
        ? ''
        : ' Quantity: ${quantity.trim()}.';

    await _addMaintenance(
      cropId: cropId,
      activity: CropMaintenanceActivity.fertilized,
      date: date,
      notes: '$fertilizerType applied.$quantityText $notes'.trim(),
      successMessage: 'Fertilizer activity recorded.',
      status: CropStatus.healthy,
    );
  }

  Future<void> harvestCrop(String cropId) async {
    final now = DateTime.now();

    await _addMaintenance(
      cropId: cropId,
      activity: CropMaintenanceActivity.harvested,
      date: now,
      notes: 'Crop marked as harvested.',
      successMessage: 'Crop marked as harvested.',
      status: CropStatus.harvested,
      growthStage: CropGrowthStage.harvested,
      progress: 1,
      harvestDate: now,
    );
  }

  Future<void> updateCrop(CropModel crop) async {
    try {
      final updatedCrop = await _repository.updateCrop(crop);
      _replaceCrop(updatedCrop, successMessage: 'Crop information updated.');
    } catch (_) {
      state = state.copyWith(errorMessage: 'Unable to update crop.');
    }
  }

  Future<void> deleteCrop(String cropId) async {
    try {
      await _repository.deleteCrop(cropId);
      final crops = state.crops.where((crop) => crop.id != cropId).toList();
      _setCrops(crops, successMessage: 'Crop deleted.', isLoading: false);
    } catch (_) {
      state = state.copyWith(errorMessage: 'Unable to delete crop.');
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
          crop.id.toLowerCase().contains(normalizedQuery);
      final matchesCropName =
          selectedCropName == null || crop.name == selectedCropName;
      final matchesPlantingDate = selectedPlantingDate == null ||
          _sameDate(crop.plantingDate, selectedPlantingDate);
      final matchesHarvestDate = selectedHarvestDate == null ||
          _sameDate(crop.estimatedHarvest, selectedHarvestDate);
      final matchesFilter = switch (selectedFilter) {
        CropFilterType.all => true,
        CropFilterType.healthy => crop.status == CropStatus.healthy,
        CropFilterType.needsWater => crop.status == CropStatus.needsWater,
        CropFilterType.needsFertilizer =>
          crop.status == CropStatus.needsFertilizer,
        CropFilterType.readyForHarvest =>
          crop.status == CropStatus.readyForHarvest,
        CropFilterType.harvested => crop.status == CropStatus.harvested,
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
        CropSortType.harvestSoon =>
          left.estimatedHarvest.compareTo(right.estimatedHarvest),
      };
    });

    return filtered;
  }

  Future<void> _addMaintenance({
    required String cropId,
    required CropMaintenanceActivity activity,
    required DateTime date,
    required String notes,
    required String successMessage,
    CropStatus? status,
    CropGrowthStage? growthStage,
    double? progress,
    DateTime? harvestDate,
    DateTime? lastWateredAt,
  }) async {
    final crop = cropById(cropId);

    if (crop == null) {
      return;
    }

    try {
      final updatedCrop = await _repository.recordMaintenance(
        crop: crop,
        activity: activity,
        date: date,
        notes: notes,
        status: status,
        growthStage: growthStage,
        progress: progress,
        harvestDate: harvestDate,
        lastWateredAt: lastWateredAt,
      );

      _replaceCrop(updatedCrop, successMessage: successMessage);
    } catch (_) {
      state = state.copyWith(errorMessage: 'Unable to record crop activity.');
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
    _subscription?.cancel();
    super.dispose();
  }
}

const _noStageChange = Object();
const _noCropNameChange = Object();
const _noPlantingDateChange = Object();
const _noHarvestDateChange = Object();

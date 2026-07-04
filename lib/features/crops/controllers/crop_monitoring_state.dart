import '../data/models/crop_model.dart';

enum CropFilterType {
  all,
  healthy,
  needsWater,
  needsFertilizer,
  readyForHarvest,
  harvested;

  String get label {
    return switch (this) {
      CropFilterType.all => 'All',
      CropFilterType.healthy => 'Healthy',
      CropFilterType.needsWater => 'Needs Water',
      CropFilterType.needsFertilizer => 'Needs Fertilizer',
      CropFilterType.readyForHarvest => 'Harvest Ready',
      CropFilterType.harvested => 'Harvested',
    };
  }
}

enum CropSortType {
  newest,
  oldest,
  name,
  harvestSoon;

  String get label {
    return switch (this) {
      CropSortType.newest => 'Newest',
      CropSortType.oldest => 'Oldest',
      CropSortType.name => 'Name',
      CropSortType.harvestSoon => 'Harvest Soon',
    };
  }
}

class CropMonitoringState {
  const CropMonitoringState({
    required this.crops,
    required this.filteredCrops,
    required this.searchQuery,
    required this.selectedFilter,
    required this.selectedCropName,
    required this.selectedPlantingDate,
    required this.selectedHarvestDate,
    required this.selectedCropId,
    required this.selectedGrowthStage,
    required this.selectedSort,
    required this.isLoading,
    required this.successMessage,
    required this.errorMessage,
  });

  factory CropMonitoringState.initial() {
    return const CropMonitoringState(
      crops: [],
      filteredCrops: [],
      searchQuery: '',
      selectedFilter: CropFilterType.all,
      selectedCropName: null,
      selectedPlantingDate: null,
      selectedHarvestDate: null,
      selectedCropId: null,
      selectedGrowthStage: null,
      selectedSort: CropSortType.newest,
      isLoading: true,
      successMessage: null,
      errorMessage: null,
    );
  }

  final List<CropModel> crops;
  final List<CropModel> filteredCrops;
  final String searchQuery;
  final CropFilterType selectedFilter;
  final String? selectedCropName;
  final DateTime? selectedPlantingDate;
  final DateTime? selectedHarvestDate;
  final String? selectedCropId;
  final CropGrowthStage? selectedGrowthStage;
  final CropSortType selectedSort;
  final bool isLoading;
  final String? successMessage;
  final String? errorMessage;

  CropModel? get selectedCrop {
    for (final crop in filteredCrops) {
      if (crop.id == selectedCropId) {
        return crop;
      }
    }

    return filteredCrops.isEmpty ? null : filteredCrops.first;
  }

  int get totalCrops => crops.length;

  int get activeCrops {
    return crops.where((crop) => crop.status != CropStatus.harvested).length;
  }

  int get harvestReadyCrops {
    return crops.where((crop) => crop.status == CropStatus.readyForHarvest).length;
  }

  List<String> get cropNames {
    return {
      for (final crop in crops) crop.name,
    }.toList()
      ..sort();
  }

  List<DateTime> get plantingDates {
    return {
      for (final crop in crops)
        DateTime(
          crop.plantingDate.year,
          crop.plantingDate.month,
          crop.plantingDate.day,
        ),
    }.toList()
      ..sort((left, right) => right.compareTo(left));
  }

  List<DateTime> get harvestDates {
    return {
      for (final crop in crops)
        DateTime(
          crop.estimatedHarvest.year,
          crop.estimatedHarvest.month,
          crop.estimatedHarvest.day,
        ),
    }.toList()
      ..sort((left, right) => right.compareTo(left));
  }

  CropMonitoringState copyWith({
    List<CropModel>? crops,
    List<CropModel>? filteredCrops,
    String? searchQuery,
    CropFilterType? selectedFilter,
    Object? selectedCropName = _noChange,
    Object? selectedPlantingDate = _noChange,
    Object? selectedHarvestDate = _noChange,
    Object? selectedCropId = _noChange,
    Object? selectedGrowthStage = _noChange,
    CropSortType? selectedSort,
    bool? isLoading,
    Object? successMessage = _noChange,
    Object? errorMessage = _noChange,
  }) {
    return CropMonitoringState(
      crops: crops ?? this.crops,
      filteredCrops: filteredCrops ?? this.filteredCrops,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      selectedCropName: selectedCropName == _noChange
          ? this.selectedCropName
          : selectedCropName as String?,
      selectedPlantingDate: selectedPlantingDate == _noChange
          ? this.selectedPlantingDate
          : selectedPlantingDate as DateTime?,
      selectedHarvestDate: selectedHarvestDate == _noChange
          ? this.selectedHarvestDate
          : selectedHarvestDate as DateTime?,
      selectedCropId: selectedCropId == _noChange
          ? this.selectedCropId
          : selectedCropId as String?,
      selectedGrowthStage: selectedGrowthStage == _noChange
          ? this.selectedGrowthStage
          : selectedGrowthStage as CropGrowthStage?,
      selectedSort: selectedSort ?? this.selectedSort,
      isLoading: isLoading ?? this.isLoading,
      successMessage: successMessage == _noChange
          ? this.successMessage
          : successMessage as String?,
      errorMessage: errorMessage == _noChange
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const _noChange = Object();

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/permission_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/content_skeleton.dart';
import '../../../authentication/providers/auth_providers.dart';
import '../../controllers/stock_inventory_controller.dart';
import '../../data/models/stock_model.dart';
import '../../providers/stock_providers.dart';
import '../widgets/stock_card.dart';
import '../widgets/stock_empty_state.dart';
import '../widgets/stock_filter_bar.dart';

class StockListScreen extends ConsumerWidget {
  const StockListScreen({super.key});

  static const _unitOptions = [
    'kg',
    'g',
    'pcs',
    'bundle',
    'crate',
    'tray',
    'sack',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockInventoryControllerProvider);
    final controller = ref.read(stockInventoryControllerProvider.notifier);
    final profile = ref.watch(authControllerProvider).profile;
    final canManageStocks =
        profile?.hasPermission(PermissionKeys.stocksManage) ?? false;

    if (state.isLoading) {
      return const _StockLoadingSkeleton();
    }

    return RefreshIndicator(
      onRefresh: controller.refreshStocks,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedTypingText(
                  'Stocks',
                  style: AppTypography.screenTitle.copyWith(
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              if (canManageStocks)
                OutlinedButton.icon(
                  onPressed: () => _showCreateStockDialog(context, controller),
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Add Item'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    textStyle: AppTypography.statusBadge,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    side: const BorderSide(color: AppColors.primaryGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          StockFilterBar(
            searchQuery: state.searchQuery,
            selectedCategory: state.selectedCategory,
            selectedFilter: state.selectedFilter,
            selectedSort: state.selectedSort,
            onSearchChanged: controller.updateSearch,
            onCategoryChanged: controller.updateCategory,
            onFilterChanged: controller.updateFilter,
            onSortChanged: controller.updateSort,
            onClear: controller.clearFilters,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (state.filteredStocks.isEmpty)
            const StockEmptyState()
          else
            _StockContent(
              stocks: state.filteredStocks,
              onStockSelected: (stock) {
                context.push(AppRoutes.stockDetailsPath(stock.id));
              },
            ),
        ],
      ),
    );
  }

  void _showCreateStockDialog(
    BuildContext context,
    StockInventoryController controller,
  ) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '0');
    final minimumController = TextEditingController(text: '0');
    final locationController = TextEditingController(text: 'Harvest Bay');
    final notesController = TextEditingController(text: 'Inventory item added.');
    var category = StockCategory.leafyVegetables;
    var selectedUnit = _unitOptions.first;
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    String? selectedImageMimeType;
    String? errorMessage;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(AppSpacing.lg),
              child: AppCard(
                backgroundColor: AppColors.secondaryBackground,
                borderColor: AppColors.inactiveBorder,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Add Item',
                              style: AppTypography.cardTitle,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Item Name'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<StockCategory>(
                        value: category,
                        dropdownColor: AppColors.secondaryBackground,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: [
                          for (final item in StockCategory.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => category = value);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: quantityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration:
                                  const InputDecoration(labelText: 'Quantity'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedUnit,
                              dropdownColor: AppColors.secondaryBackground,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                              ),
                              items: [
                                for (final unit in _unitOptions)
                                  DropdownMenuItem(
                                    value: unit,
                                    child: Text(unit),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => selectedUnit = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: minimumController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Minimum Stock Level',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(
                          labelText: 'Storage Location',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _StockImagePickerField(
                        imageBytes: selectedImageBytes,
                        imageName: selectedImageName,
                        onPickImage: () async {
                          final image = await _pickStockImage(context);

                          if (image == null) {
                            return;
                          }

                          try {
                            final bytes = await image.readAsBytes();
                            setDialogState(() {
                              selectedImageBytes = bytes;
                              selectedImageName = image.name;
                              selectedImageMimeType = _mimeTypeFor(image.name);
                              errorMessage = null;
                            });
                          } catch (_) {
                            setDialogState(() {
                              errorMessage =
                                  'Unable to read that image. Please try another photo.';
                            });
                          }
                        },
                        onRemoveImage: selectedImageBytes == null
                            ? null
                            : () {
                                setDialogState(() {
                                  selectedImageBytes = null;
                                  selectedImageName = null;
                                  selectedImageMimeType = null;
                                });
                              },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(labelText: 'Notes'),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          errorMessage!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryText,
                              side: const BorderSide(
                                color: AppColors.inactiveBorder,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final name = nameController.text.trim();
                              final quantity =
                                  double.tryParse(quantityController.text) ?? -1;
                              final minimum =
                                  double.tryParse(minimumController.text) ?? -1;

                              if (name.isEmpty) {
                                setDialogState(() {
                                  errorMessage = 'Item name is required.';
                                });
                                return;
                              }

                              if (quantity < 0 || minimum < 0) {
                                setDialogState(() {
                                  errorMessage =
                                      'Quantity values cannot be negative.';
                                });
                                return;
                              }

                              await controller.createStock(
                                StockModel(
                                  id: 'new',
                                  displayId: 'STK-000',
                                  name: name,
                                  category: category,
                                  currentQuantity: quantity,
                                  unit: selectedUnit,
                                  storageLocation:
                                      locationController.text.trim().isEmpty
                                          ? 'Unassigned'
                                          : locationController.text.trim(),
                                  minimumStockLevel: minimum,
                                  supplier: 'Farm Harvest',
                                  dateAdded: DateTime.now(),
                                  lastUpdated: DateTime.now(),
                                  notes: notesController.text.trim(),
                                  transactions: const [],
                                ),
                                imageUpload: selectedImageBytes == null
                                    ? null
                                    : StockImageUpload(
                                        bytes: selectedImageBytes!,
                                        fileName:
                                            selectedImageName ?? 'stock-image',
                                        mimeType: selectedImageMimeType ??
                                            'image/jpeg',
                                      ),
                              );

                              if (context.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Save'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              side: const BorderSide(
                                color: AppColors.primaryGreen,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _mimeTypeFor(String fileName) {
    final lowerName = fileName.toLowerCase();

    if (lowerName.endsWith('.png')) {
      return 'image/png';
    }

    if (lowerName.endsWith('.webp')) {
      return 'image/webp';
    }

    return 'image/jpeg';
  }

  Future<XFile?> _pickStockImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.secondaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.md),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Upload Stock Image',
                        style: AppTypography.cardTitle,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) {
      return null;
    }

    try {
      return ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Image picker is not ready. Restart the app and try again.',
            ),
          ),
        );
      }

      return null;
    }
  }
}

class _StockImagePickerField extends StatelessWidget {
  const _StockImagePickerField({
    required this.imageBytes,
    required this.imageName,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  final Uint8List? imageBytes;
  final String? imageName;
  final VoidCallback onPickImage;
  final VoidCallback? onRemoveImage;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPickImage,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            border: Border.all(color: AppColors.inactiveBorder),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: SizedBox.square(
                    dimension: 64,
                    child: imageBytes == null
                        ? ColoredBox(
                            color: AppColors.secondaryBackground,
                            child: Icon(
                              Icons.image_outlined,
                              color: AppColors.primaryGreen,
                            ),
                          )
                        : Image.memory(imageBytes!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stock Image', style: AppTypography.caption),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        imageName ?? 'No image selected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.small,
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onPickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Choose'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
                if (onRemoveImage != null)
                  IconButton(
                    tooltip: 'Remove image',
                    onPressed: onRemoveImage,
                    icon: const Icon(Icons.close),
                    color: AppColors.secondaryText,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StockLoadingSkeleton extends StatelessWidget {
  const _StockLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SkeletonLine(widthFactor: 0.28, height: 30),
        const SizedBox(height: AppSpacing.xl),
        const SkeletonCard(
          children: [
            SkeletonLine(widthFactor: 0.92),
            SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: SkeletonBlock(height: 34)),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: SkeletonBlock(height: 34)),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: SkeletonBlock(height: 34)),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const SkeletonLine(widthFactor: 0.45, height: 18),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: const [
              SizedBox(width: 280, child: _StockCardSkeleton()),
              SizedBox(width: AppSpacing.md),
              SizedBox(width: 280, child: _StockCardSkeleton()),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SkeletonLine(widthFactor: 0.5, height: 18),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: const [
              SizedBox(width: 280, child: _StockCardSkeleton()),
              SizedBox(width: AppSpacing.md),
              SizedBox(width: 280, child: _StockCardSkeleton()),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockCardSkeleton extends StatelessWidget {
  const _StockCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      children: [
        SkeletonLine(widthFactor: 0.72, height: 18),
        SizedBox(height: AppSpacing.sm),
        SkeletonLine(widthFactor: 0.36),
        SizedBox(height: AppSpacing.md),
        Center(child: SkeletonBlock(height: 94, width: 110)),
        SizedBox(height: AppSpacing.md),
        SkeletonLine(widthFactor: 0.9),
        SizedBox(height: AppSpacing.sm),
        SkeletonLine(widthFactor: 0.75),
        SizedBox(height: AppSpacing.md),
        SkeletonBlock(height: 32),
      ],
    );
  }
}

class _StockContent extends StatelessWidget {
  const _StockContent({
    required this.stocks,
    required this.onStockSelected,
  });

  final List<StockModel> stocks;
  final ValueChanged<StockModel> onStockSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in _groupStocksByCategory(stocks).entries) ...[
          _StockGroup(
            title: '${group.key.label} (${group.value.length})',
            stocks: group.value,
            onStockSelected: onStockSelected,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }

  Map<StockCategory, List<StockModel>> _groupStocksByCategory(
    List<StockModel> stocks,
  ) {
    final sortedStocks = [...stocks]
      ..sort((left, right) {
        final categoryCompare = left.category.label.compareTo(
          right.category.label,
        );

        if (categoryCompare != 0) {
          return categoryCompare;
        }

        return left.name.compareTo(right.name);
      });
    final grouped = <StockCategory, List<StockModel>>{};

    for (final stock in sortedStocks) {
      grouped.putIfAbsent(stock.category, () => []).add(stock);
    }

    return grouped;
  }
}

class _StockGroup extends StatelessWidget {
  const _StockGroup({
    required this.title,
    required this.stocks,
    required this.onStockSelected,
  });

  final String title;
  final List<StockModel> stocks;
  final ValueChanged<StockModel> onStockSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedTypingText(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.cardTitle.copyWith(
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < stocks.length; index++) ...[
                SizedBox(
                  width: 280,
                  child: StockCard(
                    stock: stocks[index],
                    onView: () => onStockSelected(stocks[index]),
                  ),
                ),
                if (index != stocks.length - 1)
                  const SizedBox(width: AppSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

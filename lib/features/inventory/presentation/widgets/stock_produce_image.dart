import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class StockProduceImage extends StatelessWidget {
  const StockProduceImage({
    required this.itemName,
    this.imageUrl,
    this.assetPath,
    this.size = 72,
    super.key,
  });

  final String itemName;
  final String? imageUrl;
  final String? assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolvedAssetPath = assetPath ?? _assetPathFor(itemName);

    return SizedBox.square(
      dimension: size,
      child: imageUrl != null && imageUrl!.trim().isNotEmpty
          ? Image.network(
              imageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _FallbackAssetImage(
                assetPath: resolvedAssetPath,
                size: size,
              ),
            )
          : _FallbackAssetImage(assetPath: resolvedAssetPath, size: size),
    );
  }

  String? _assetPathFor(String itemName) {
    final normalizedName = itemName.trim().toLowerCase();

    if (normalizedName.contains('sitaw')) {
      return 'assets/images/stocks/sitaw.png';
    }

    if (normalizedName.contains('calamansi')) {
      return 'assets/images/stocks/calamansi.png';
    }

    if (normalizedName.contains('peanut')) {
      return 'assets/images/stocks/peanut.png';
    }

    if (normalizedName.contains('eggplant')) {
      return 'assets/images/stocks/eggplant.png';
    }

    if (normalizedName.contains('tomato')) {
      return 'assets/images/stocks/tomato.png';
    }

    if (normalizedName.contains('pechay')) {
      return 'assets/images/stocks/pechay.png';
    }

    if (normalizedName.contains('okra')) {
      return 'assets/images/stocks/okra.png';
    }

    if (normalizedName.contains('kangkong')) {
      return 'assets/images/stocks/kangkong.png';
    }

    if (normalizedName.contains('lettuce')) {
      return 'assets/images/stocks/lettuce.png';
    }

    if (normalizedName.contains('squash')) {
      return 'assets/images/stocks/squash.png';
    }

    return null;
  }
}

class _FallbackAssetImage extends StatelessWidget {
  const _FallbackAssetImage({
    required this.assetPath,
    required this.size,
  });

  final String? assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (assetPath == null) {
      return _PlaceholderIcon(size: size);
    }

    return Image.asset(
      assetPath!,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _PlaceholderIcon(size: size),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  const _PlaceholderIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.eco_outlined,
      color: AppColors.primaryGreen,
      size: size * 0.72,
    );
  }
}

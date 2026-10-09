import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_image.dart';
import '../models/mock_shop_product.dart';

/// Square product photo for shop lists. Uses the product's own image, and
/// only falls back to a category emoji when the product has none.
class ShopProductThumb extends StatelessWidget {
  const ShopProductThumb({super.key, required this.product, this.size = 48});
  final MockShopProduct product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (emoji, tint) = switch (product.visualType) {
      ShopProductVisual.apple => ('🍎', AppColors.rejectBackground),
      ShopProductVisual.banana => ('🍌', AppColors.bananaBackground),
      ShopProductVisual.milk => ('🥛', AppColors.milkBackground),
      ShopProductVisual.bread => ('🍞', AppColors.lightOrange),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .21),
      child: SizedBox(
        width: size,
        height: size,
        child: ExcludeSemantics(
          child: AppImage(
            source: product.imageUrl,
            width: size,
            height: size,
            fallback: ColoredBox(
              color: tint,
              child: Center(
                child: Text(emoji, style: TextStyle(fontSize: size * .55)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

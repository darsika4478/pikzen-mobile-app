import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mock_shop_product.dart';

class ProductListCard extends StatelessWidget {
  const ProductListCard({
    super.key,
    required this.product,
    required this.onSelected,
  });
  final MockShopProduct product;
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) {
    final (visual, tint) = switch (product.visualType) {
      ShopProductVisual.apple => ('🍎', AppColors.rejectBackground),
      ShopProductVisual.banana => ('🍌', AppColors.bananaBackground),
      ShopProductVisual.milk => ('🥛', AppColors.milkBackground),
      ShopProductVisual.bread => ('🍞', AppColors.lightOrange),
    };
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onSelected,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ExcludeSemantics(
                    child: Text(visual, style: const TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        product.price,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${product.category} • ${product.stockQuantity} in stock',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 5),
                      ProductStatusBadge(label: product.status),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
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

class ProductStatusBadge extends StatelessWidget {
  const ProductStatusBadge({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.softGreen,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 9,
        color: AppColors.primary,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mock_shop_product.dart';

class ProductImagePreview extends StatelessWidget {
  const ProductImagePreview({
    super.key,
    required this.product,
    required this.onChange,
  });
  final MockShopProduct? product;
  final VoidCallback onChange;
  @override
  Widget build(BuildContext context) {
    if (product == null) {
      return SizedBox(
        width: 82,
        height: 82,
        child: CustomPaint(
          foregroundPainter: const _DashedImageBorder(),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onChange,
              borderRadius: BorderRadius.circular(12),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.softGreen,
                    child: Icon(
                      Icons.camera_alt_outlined,
                      color: AppColors.primary,
                      size: 19,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Add Photo',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final asset = switch (product?.visualType) {
      ShopProductVisual.apple => 'assets/images/Apples Product.png',
      ShopProductVisual.milk => 'assets/images/Milk Product.png',
      ShopProductVisual.bread => 'assets/images/Roast bun.png',
      _ => null,
    };
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        children: [
          CustomPaint(
            painter: const _DashedImageBorder(),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 76,
                  height: 76,
                  color: AppColors.softGreen,
                  alignment: Alignment.center,
                  child: asset != null
                      ? Image.asset(
                          asset,
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                        )
                      : product == null
                      ? const Icon(
                          Icons.image_outlined,
                          color: AppColors.primary,
                          size: 28,
                        )
                      : const Text('🍌', style: TextStyle(fontSize: 38)),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: IconButton(
              onPressed: onChange,
              tooltip: 'Change product image',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
                minimumSize: const Size(28, 28),
                padding: const EdgeInsets.all(5),
                side: const BorderSide(color: AppColors.surface, width: 2),
                shape: const CircleBorder(),
              ),
              icon: const Icon(Icons.camera_alt_outlined, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedImageBorder extends CustomPainter {
  const _DashedImageBorder();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    final paint = Paint()
      ..color = AppColors.primaryLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += 7) {
        canvas.drawPath(metric.extractPath(offset, offset + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedImageBorder oldDelegate) => false;
}

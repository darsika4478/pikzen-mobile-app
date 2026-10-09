import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_image.dart';

/// Product photo picker tile for the add/edit form. Shows the current photo
/// (bundled, web or uploaded) or an "Add Photo" prompt.
class ProductImagePreview extends StatelessWidget {
  const ProductImagePreview({
    super.key,
    required this.imageUrl,
    required this.onChange,
    this.onRemove,
    this.busy = false,
  });
  final String? imageUrl;
  final VoidCallback onChange;

  /// Shown as a small "Remove" action when a photo is set.
  final VoidCallback? onRemove;
  final bool busy;

  static const _size = 132.0;

  @override
  Widget build(BuildContext context) {
    final hasImage = AppImage.isUsable(imageUrl);
    final prompt = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.softGreen,
          child: Icon(
            Icons.add_a_photo_outlined,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Add Photo',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'JPG or PNG',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.secondaryText.withValues(alpha: .9),
          ),
        ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _size,
          height: _size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                foregroundPainter: hasImage ? null : const _DashedImageBorder(),
                child: Material(
                  color: hasImage ? AppColors.softGreen : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: busy ? null : onChange,
                    child: SizedBox.expand(
                      child: busy
                          ? const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : hasImage
                          ? AppImage(
                              source: imageUrl,
                              width: _size,
                              height: _size,
                              fallback: prompt,
                            )
                          : prompt,
                    ),
                  ),
                ),
              ),
              if (hasImage)
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: IconButton(
                    onPressed: busy ? null : onChange,
                    tooltip: 'Change product image',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.surface,
                      minimumSize: const Size(34, 34),
                      padding: const EdgeInsets.all(6),
                      side: const BorderSide(
                        color: AppColors.surface,
                        width: 2,
                      ),
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  ),
                ),
            ],
          ),
        ),
        if (hasImage && onRemove != null)
          TextButton.icon(
            onPressed: busy ? null : onRemove,
            style: TextButton.styleFrom(foregroundColor: AppColors.rejectRed),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Remove photo', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}

class _DashedImageBorder extends CustomPainter {
  const _DashedImageBorder();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      );
    final paint = Paint()
      ..color = AppColors.primaryLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final metric in path.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += 7) {
        canvas.drawPath(metric.extractPath(offset, offset + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedImageBorder oldDelegate) => false;
}

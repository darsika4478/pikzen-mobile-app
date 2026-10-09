import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/shop_insights.dart';

/// "Online • Store Open" during pickup hours, "Store Closed" otherwise.
class StoreStatusBadge extends StatelessWidget {
  const StoreStatusBadge({super.key, this.now});

  /// Test seam; defaults to the current time.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final status = storeStatusAt(now ?? DateTime.now());
    final color = status.open ? AppColors.primary : AppColors.secondaryText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.open ? AppColors.softGreen : AppColors.mutedSurface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: status.open
              ? AppColors.primary.withValues(alpha: .2)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 7),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: status.open ? AppColors.darkGreen : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

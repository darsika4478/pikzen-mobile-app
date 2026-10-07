import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/availability_item.dart';
import '../models/mock_order_details.dart';

class AvailabilityProductCard extends StatelessWidget {
  const AvailabilityProductCard({super.key, required this.item});
  final AvailabilityItem item;

  @override
  Widget build(BuildContext context) {
    final (visual, tint) = switch (item.visualType) {
      OrderItemType.apple => ('🍎', AppColors.rejectBackground),
      OrderItemType.banana => ('🍌', AppColors.bananaBackground),
      OrderItemType.milk => ('🥛', AppColors.milkBackground),
      OrderItemType.other => ('📦', AppColors.softGreen),
    };
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: item.isAvailable
                  ? AppColors.border
                  : AppColors.rejectBorder,
            ),
          ),
          child: Stack(
            children: [
              if (!item.isAvailable)
                const Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: SizedBox(
                    width: 3,
                    child: ColoredBox(color: AppColors.rejectRed),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          visual,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Qty: ${item.quantity} • ${item.price}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    AvailabilityStatusBadge(isAvailable: item.isAvailable),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AvailabilityStatusBadge extends StatelessWidget {
  const AvailabilityStatusBadge({super.key, required this.isAvailable});
  final bool isAvailable;
  @override
  Widget build(BuildContext context) {
    final color = isAvailable ? AppColors.primary : AppColors.rejectRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: isAvailable ? AppColors.softGreen : AppColors.rejectBackground,
        border: Border.all(
          color: isAvailable ? AppColors.softGreen : AppColors.rejectBorder,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAvailable ? Icons.check_rounded : Icons.close_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            isAvailable ? 'In Stock' : 'Not Available',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

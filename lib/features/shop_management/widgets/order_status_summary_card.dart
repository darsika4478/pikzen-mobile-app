import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mock_order_details.dart';
import 'dashboard_surface.dart';

class OrderStatusSummaryCard extends StatelessWidget {
  const OrderStatusSummaryCard({super.key, required this.order});
  final MockOrderDetails order;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 12,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        const DashboardIconTile(icon: Icons.inventory_2_outlined, size: 38),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${order.items.length} items • ${order.total}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Customer: ${order.customerName}',
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.mutedSurface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Standard',
            style: TextStyle(fontSize: 9, color: AppColors.secondaryText),
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mock_order_details.dart';

class OrderDetailsHeader extends StatelessWidget {
  const OrderDetailsHeader({
    super.key,
    required this.order,
    required this.onBack,
  });
  final MockOrderDetails order;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    child: Row(
      children: [
        Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primaryText,
              side: const BorderSide(color: AppColors.border),
              shape: const CircleBorder(),
              minimumSize: const Size(40, 40),
            ),
            icon: const Icon(Icons.chevron_left_rounded, size: 24),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              Text(
                'Order ${order.orderId}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                order.orderType,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            order.status,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    ),
  );
}

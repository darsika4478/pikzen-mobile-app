import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mock_order_details.dart';

class CustomerChatHeader extends StatelessWidget {
  const CustomerChatHeader({
    super.key,
    required this.order,
    required this.onBack,
    required this.onCall,
  });
  final MockOrderDetails order;
  final VoidCallback onBack;
  final VoidCallback onCall;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
        ),
        Stack(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: AppColors.softGreen,
              child: Text(
                order.initials,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chat with ${order.customerName}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Order ${order.orderId} • '),
                    const TextSpan(
                      text: 'Active',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: onCall,
          tooltip: 'Call ${order.customerName}',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.softGreen,
            foregroundColor: AppColors.primary,
            shape: const CircleBorder(),
            minimumSize: const Size(40, 40),
          ),
          icon: const Icon(Icons.phone_rounded, size: 18),
        ),
      ],
    ),
  );
}

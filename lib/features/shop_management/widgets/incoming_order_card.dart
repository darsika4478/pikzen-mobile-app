import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mock_incoming_order.dart';
import 'order_action_buttons.dart';

class IncomingOrderCard extends StatelessWidget {
  const IncomingOrderCard({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onReject,
    required this.onDetails,
  });
  final MockIncomingOrder order;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onDetails;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 14,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              order.orderId,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Flexible(child: OrderStatusBadge(label: order.timeAgo)),
            const Spacer(),
            SizedBox(
              width: 26,
              height: 28,
              child: IconButton(
                onPressed: onDetails,
                tooltip: 'View ${order.orderId}',
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          order.customerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.access_time_rounded,
              size: 13,
              color: AppColors.secondaryText,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                order.dateTime,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Order Total',
                style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
              ),
            ),
            Text(
              order.total,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 13),
        OrderActionButtons(onAccept: onAccept, onReject: onReject),
      ],
    ),
  );
}

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.softGreen,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.primary,
      ),
    ),
  );
}

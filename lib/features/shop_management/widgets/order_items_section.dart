import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mock_order_details.dart';

class OrderItemsSection extends StatelessWidget {
  const OrderItemsSection({super.key, required this.order});
  final MockOrderDetails order;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '${order.items.length} ITEMS INCLUDED',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: .4,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              order.pickupType,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < order.items.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(child: OrderProductCard(item: order.items[index])),
          ],
        ],
      ),
    ],
  );
}

class OrderProductCard extends StatelessWidget {
  const OrderProductCard({super.key, required this.item});
  final MockOrderItem item;
  @override
  Widget build(BuildContext context) {
    final (visual, tint) = switch (item.type) {
      OrderItemType.apple => ('🍎', AppColors.rejectBackground),
      OrderItemType.banana => ('🍌', AppColors.bananaBackground),
      OrderItemType.milk => ('🥛', AppColors.milkBackground),
      OrderItemType.other => ('📦', AppColors.softGreen),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.mutedSurface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
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
              child: Text(visual, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Qty: ${item.quantity}',
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mock_order_details.dart';

class CustomerInfoSection extends StatelessWidget {
  const CustomerInfoSection({
    super.key,
    required this.order,
    required this.onCall,
  });
  final MockOrderDetails order;
  final VoidCallback onCall;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.softGreen,
        child: Text(
          order.initials,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.customerName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.dateTime,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.3,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(width: 5),
      IconButton(
        onPressed: onCall,
        tooltip: 'Call customer',
        style: IconButton.styleFrom(
          backgroundColor: AppColors.softGreen,
          foregroundColor: AppColors.primary,
          shape: const CircleBorder(),
          minimumSize: const Size(40, 40),
        ),
        icon: const Icon(Icons.phone_rounded, size: 18),
      ),
    ],
  );
}

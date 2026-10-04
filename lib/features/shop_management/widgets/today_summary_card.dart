import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'dashboard_surface.dart';
import 'summary_item_card.dart';

class TodaySummaryCard extends StatelessWidget {
  const TodaySummaryCard({super.key, required this.onViewAll});
  final VoidCallback onViewAll;
  @override
  Widget build(BuildContext context) => DashboardSurface(
    child: Column(
      children: [
        Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.primary,
              size: 16,
            ),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                "TODAY'S SUMMARY",
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: .5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(48, 32),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SummaryItemCard(
                icon: Icons.shopping_bag_outlined,
                value: '12',
                label: 'New Orders',
                status: '+3 new',
                showBadge: true,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: SummaryItemCard(
                icon: Icons.inventory_2_outlined,
                value: '28',
                label: 'Products Listed',
                status: 'Active',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

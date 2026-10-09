import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/shop_insights.dart';
import 'checklist_item.dart';
import 'dashboard_surface.dart';

/// Today's shop tasks, each derived from live orders, stock and chats.
class OperationalChecklist extends StatelessWidget {
  const OperationalChecklist({
    super.key,
    required this.newOrders,
    required this.lowStock,
    this.unansweredQueries = 0,
    this.lastOrderHandledAt,
    this.onOrders,
    this.onStock,
    this.onQueries,
  });
  final int newOrders;
  final int lowStock;
  final int unansweredQueries;

  /// When the latest order was accepted; shown once orders are up to date.
  final DateTime? lastOrderHandledAt;
  final VoidCallback? onOrders;
  final VoidCallback? onStock;
  final VoidCallback? onQueries;

  @override
  Widget build(BuildContext context) {
    final done = [
      newOrders == 0,
      lowStock == 0,
      unansweredQueries == 0,
    ].where((value) => value).length;
    return DashboardSurface(
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'OPERATIONAL CHECKLIST',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: .6,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$done of 3 Done',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ChecklistItem(
            title: newOrders == 0
                ? 'Check incoming orders'
                : 'Review $newOrders new order${newOrders == 1 ? '' : 's'}',
            status: newOrders > 0
                ? '$newOrders pending'
                : lastOrderHandledAt == null
                ? 'Up to date'
                : formatShopTime(lastOrderHandledAt!),
            icon: Icons.check_rounded,
            completed: newOrders == 0,
            needsAction: newOrders > 0,
            onTap: onOrders,
          ),
          const SizedBox(height: 8),
          ChecklistItem(
            title: 'Update low stock items',
            status: lowStock == 0 ? 'Up to date' : 'Action needed',
            icon: Icons.inventory_2_outlined,
            completed: lowStock == 0,
            needsAction: lowStock > 0,
            onTap: onStock,
          ),
          const SizedBox(height: 8),
          ChecklistItem(
            title: unansweredQueries == 0
                ? 'Respond to customer queries'
                : 'Respond to $unansweredQueries customer '
                      '${unansweredQueries == 1 ? 'query' : 'queries'}',
            status: unansweredQueries == 0 ? 'All replied' : 'Pending',
            icon: Icons.chat_bubble_outline_rounded,
            completed: unansweredQueries == 0,
            onTap: onQueries,
          ),
        ],
      ),
    );
  }
}

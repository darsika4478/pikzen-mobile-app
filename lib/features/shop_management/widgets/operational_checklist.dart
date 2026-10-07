import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'checklist_item.dart';
import 'dashboard_surface.dart';

class OperationalChecklist extends StatelessWidget {
  const OperationalChecklist({
    super.key,
    required this.newOrders,
    required this.lowStock,
  });
  final int newOrders;
  final int lowStock;
  @override
  Widget build(BuildContext context) => DashboardSurface(
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
              '${(newOrders == 0 ? 1 : 0) + (lowStock == 0 ? 1 : 0)} of 2 Done',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ChecklistItem(
          title: 'Check incoming orders',
          status: newOrders == 0 ? 'Up to date' : '$newOrders pending',
          icon: Icons.check_rounded,
          completed: newOrders == 0,
          needsAction: newOrders > 0,
        ),
        const SizedBox(height: 8),
        ChecklistItem(
          title: 'Update low stock items',
          status: lowStock == 0 ? 'Up to date' : '$lowStock low',
          icon: Icons.inventory_2_outlined,
          completed: lowStock == 0,
          needsAction: lowStock > 0,
        ),
      ],
    ),
  );
}

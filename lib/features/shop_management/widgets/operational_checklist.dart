import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'checklist_item.dart';
import 'dashboard_surface.dart';

class OperationalChecklist extends StatelessWidget {
  const OperationalChecklist({super.key});
  @override
  Widget build(BuildContext context) => const DashboardSurface(
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
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
            SizedBox(width: 4),
            Text(
              '1 of 3 Done',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: 14),
        ChecklistItem(
          title: 'Check incoming orders',
          status: '10:00 AM',
          icon: Icons.check_rounded,
          completed: true,
        ),
        SizedBox(height: 8),
        ChecklistItem(
          title: 'Update low stock items',
          status: 'Action needed',
          icon: Icons.inventory_2_outlined,
          needsAction: true,
        ),
        SizedBox(height: 8),
        ChecklistItem(
          title: 'Respond to 2 customer queries',
          status: 'Pending',
          icon: Icons.chat_bubble_outline_rounded,
        ),
      ],
    ),
  );
}

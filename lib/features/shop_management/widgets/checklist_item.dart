import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'dashboard_surface.dart';

class ChecklistItem extends StatelessWidget {
  const ChecklistItem({
    super.key,
    required this.title,
    required this.status,
    required this.icon,
    this.completed = false,
    this.needsAction = false,
  });
  final String title;
  final String status;
  final IconData icon;
  final bool completed;
  final bool needsAction;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.mutedSurface,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        DashboardIconTile(
          icon: icon,
          size: 28,
          color: completed
              ? AppColors.surface
              : needsAction
              ? AppColors.warning
              : AppColors.secondaryText,
          background: completed
              ? AppColors.primary
              : needsAction
              ? AppColors.lightOrange
              : AppColors.border,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          status,
          style: TextStyle(
            fontSize: 9,
            color: needsAction ? AppColors.warning : AppColors.secondaryText,
          ),
        ),
      ],
    ),
  );
}

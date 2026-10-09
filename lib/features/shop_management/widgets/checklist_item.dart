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
    this.onTap,
  });
  final String title;
  final String status;
  final IconData icon;
  final bool completed;
  final bool needsAction;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.mutedSurface,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: completed ? AppColors.secondaryText : null,
                  decoration: completed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              status,
              style: TextStyle(
                fontSize: 9,
                color: needsAction
                    ? AppColors.warning
                    : AppColors.secondaryText,
                fontWeight: needsAction ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.secondaryText,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

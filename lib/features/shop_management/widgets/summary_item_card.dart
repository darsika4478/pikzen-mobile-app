import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'dashboard_surface.dart';

class SummaryItemCard extends StatelessWidget {
  const SummaryItemCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.status,
    this.showBadge = false,
  });
  final IconData icon;
  final String value;
  final String label;
  final String status;
  final bool showBadge;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.veryLightGreen,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DashboardIconTile(icon: icon, size: 30),
            const SizedBox(width: 4),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: showBadge ? AppColors.softGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: showBadge
                          ? AppColors.primary
                          : AppColors.secondaryText,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          value,
          style: const TextStyle(
            fontSize: 32,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: -.8,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
        ),
      ],
    ),
  );
}

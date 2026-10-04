import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'dashboard_surface.dart';

class DashboardActionCard extends StatelessWidget {
  const DashboardActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
    this.isWarning = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;
  final bool isWarning;
  @override
  Widget build(BuildContext context) {
    final color = isWarning ? AppColors.warning : AppColors.primary;
    final tint = isWarning ? AppColors.lightOrange : AppColors.softGreen;
    return DashboardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DashboardIconTile(
                icon: icon,
                color: color,
                background: tint,
                size: 38,
              ),
              const Spacer(),
              if (isWarning)
                const Icon(Icons.circle, color: AppColors.warning, size: 6),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.4,
              color: isWarning ? AppColors.warning : AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 12),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                backgroundColor: tint,
                foregroundColor: color,
                side: BorderSide(
                  color: isWarning
                      ? AppColors.orangeBorder
                      : AppColors.softGreen,
                ),
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

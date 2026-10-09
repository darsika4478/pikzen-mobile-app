import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'dashboard_surface.dart';
import '../models/shop_insights.dart';
import 'store_status_badge.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.onNotifications,
    required this.onShop,
    required this.shopName,
    this.alertCount = 0,
  });
  final VoidCallback onNotifications;
  final VoidCallback onShop;
  final String shopName;

  /// Shows a dot on the bell when anything needs attention.
  final int alertCount;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 42,
              height: 42,
              child: Transform.scale(
                scale: 2.1,
                child: Image.asset(
                  'assets/logos/pikzen_logo.jpeg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const DashboardIconTile(
                        icon: Icons.shopping_basket_outlined,
                      ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PikZen',
                  style: TextStyle(
                    fontSize: 23,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.7,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'SHOP PARTNER',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              children: [
                IconButton(
                  onPressed: onNotifications,
                  tooltip: alertCount == 0
                      ? 'Notifications'
                      : 'Notifications, $alertCount new',
                  icon: const Icon(Icons.notifications_none_rounded, size: 23),
                ),
                if (alertCount > 0)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const StoreStatusBadge(),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greetingFor(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 27,
                    height: 1.2,
                    letterSpacing: -.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$shopName • ${formatShopDay(DateTime.now())}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onShop,
            tooltip: 'Store profile',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.softGreen,
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              fixedSize: const Size(46, 46),
            ),
            icon: const Icon(Icons.storefront_outlined, size: 25),
          ),
        ],
      ),
    ],
  );
}

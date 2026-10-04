import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class IncomingOrdersHeader extends StatelessWidget {
  const IncomingOrdersHeader({
    super.key,
    required this.onBack,
    required this.onNotifications,
  });
  final VoidCallback onBack;
  final VoidCallback onNotifications;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        onPressed: onBack,
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
      ),
      const SizedBox(width: 2),
      const Expanded(
        child: Text(
          'Incoming Orders',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        onPressed: onNotifications,
        tooltip: 'Notifications',
        style: IconButton.styleFrom(
          backgroundColor: AppColors.softGreen,
          foregroundColor: AppColors.primary,
          shape: const CircleBorder(),
          minimumSize: const Size(40, 40),
        ),
        icon: const Icon(Icons.notifications_none_rounded, size: 22),
      ),
    ],
  );
}

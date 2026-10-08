import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class StoreStatusBadge extends StatelessWidget {
  const StoreStatusBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.softGreen,
      borderRadius: BorderRadius.circular(30),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: AppColors.primary, size: 6),
        SizedBox(width: 6),
        Text(
          'Approved Shop Partner',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.darkGreen,
          ),
        ),
      ],
    ),
  );
}

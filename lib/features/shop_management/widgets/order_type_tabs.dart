import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class OrderTypeTabs extends StatelessWidget {
  const OrderTypeTabs({
    super.key,
    required this.scheduled,
    required this.onChanged,
    this.newCount = 12,
  });
  final bool scheduled;
  final ValueChanged<bool> onChanged;
  final int newCount;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.border,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: _tab(
              label: 'New',
              selected: !scheduled,
              value: false,
              badge: true,
            ),
          ),
          Expanded(
            child: _tab(label: 'Scheduled', selected: scheduled, value: true),
          ),
        ],
      ),
    ),
  );

  Widget _tab({
    required String label,
    required bool selected,
    required bool value,
    bool badge = false,
  }) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => onChanged(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.surface : AppColors.secondaryText,
                ),
              ),
              if (badge) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryLight
                        : AppColors.softGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$newCount',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.surface : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// The preview has one active stage; 4 indicates all four stages are complete.
class OrderStatusTimeline extends StatelessWidget {
  const OrderStatusTimeline({
    super.key,
    required this.activeStage,
    required this.acceptedAt,
  });
  final int activeStage;
  final String acceptedAt;
  static const titles = [
    'Order Accepted',
    'Preparing',
    'Ready for Pickup',
    'Collected',
  ];

  @override
  Widget build(BuildContext context) {
    final descriptions = [
      acceptedAt,
      'Items being packed by merchant',
      'Waiting for preparation to complete',
      'Customer pick up from store',
    ];
    return Column(
      children: [
        for (var index = 0; index < titles.length; index++)
          OrderStatusStep(
            title: titles[index],
            description: index == 2 && activeStage >= 2
                ? 'Ready for customer pickup'
                : descriptions[index],
            completed: index < activeStage,
            active: index == activeStage,
            last: index == titles.length - 1,
          ),
      ],
    );
  }
}

class OrderStatusStep extends StatelessWidget {
  const OrderStatusStep({
    super.key,
    required this.title,
    required this.description,
    required this.completed,
    required this.active,
    required this.last,
  });
  final String title;
  final String description;
  final bool completed;
  final bool active;
  final bool last;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '$title, ${completed
            ? 'completed'
            : active
            ? 'in progress'
            : 'pending'}',
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Stack(
              children: [
                if (!last)
                  Positioned(
                    top: 34,
                    bottom: 0,
                    left: 17,
                    width: 2,
                    child: ColoredBox(
                      color: completed ? AppColors.primary : AppColors.border,
                    ),
                  ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completed
                        ? AppColors.primary
                        : active
                        ? AppColors.veryLightGreen
                        : AppColors.surface,
                    border: Border.all(
                      color: completed || active
                          ? AppColors.primary
                          : AppColors.border,
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Icon(
                    completed
                        ? Icons.check_rounded
                        : active
                        ? Icons.timer_outlined
                        : Icons.circle,
                    size: completed || active ? 19 : 5,
                    color: completed
                        ? AppColors.surface
                        : active
                        ? AppColors.primary
                        : AppColors.inactiveText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3, bottom: last ? 0 : 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: completed || active
                              ? AppColors.primaryText
                              : AppColors.inactiveText,
                        ),
                      ),
                      if (active)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.softGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'In progress',
                            style: TextStyle(
                              fontSize: 8,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.4,
                      color: active
                          ? AppColors.primary
                          : completed
                          ? AppColors.secondaryText
                          : AppColors.inactiveText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

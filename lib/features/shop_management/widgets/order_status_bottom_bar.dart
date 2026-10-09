import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class OrderStatusBottomBar extends StatelessWidget {
  const OrderStatusBottomBar({
    super.key,
    required this.activeStage,
    required this.onAdvance,
  });
  final int activeStage;
  final VoidCallback? onAdvance;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: activeStage == 4 ? null : onAdvance,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      activeStage == 4
                          ? 'Order Completed'
                          : activeStage == 3
                          ? 'Mark as Collected'
                          : activeStage == 2
                          ? 'Mark as Ready'
                          : 'Start Preparing',
                    ),
                    if (activeStage != 4) ...[
                      const SizedBox(width: 9),
                      const Icon(Icons.arrow_forward_rounded, size: 17),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mock_order_details.dart';
import '../widgets/order_status_timeline.dart';
import '../widgets/order_status_summary_card.dart';
import '../widgets/order_status_bottom_bar.dart';

class UpdateOrderStatusScreen extends StatefulWidget {
  const UpdateOrderStatusScreen({super.key, required this.order});
  final MockOrderDetails order;
  @override
  State<UpdateOrderStatusScreen> createState() =>
      _UpdateOrderStatusScreenState();
}

class _UpdateOrderStatusScreenState extends State<UpdateOrderStatusScreen> {
  int _activeStage = 1;
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(
        'confirm-availability',
        pathParameters: {'orderId': widget.order.orderId.substring(1)},
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              UpdateOrderStatusHeader(
                orderId: widget.order.orderId,
                onBack: _back,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: OrderStatusTimeline(
                          activeStage: _activeStage,
                          acceptedAt: switch (widget.order.orderId) {
                            '#P2002' => '12 Dec, 11:35 AM',
                            '#P2003' => '12 Dec, 01:05 PM',
                            _ => '12 Dec, 10:05 AM',
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      OrderStatusSummaryCard(order: widget.order),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: OrderStatusBottomBar(
      activeStage: _activeStage,
      onAdvance: () => setState(() => _activeStage = _activeStage == 1 ? 2 : 4),
    ),
  );
}

class UpdateOrderStatusHeader extends StatelessWidget {
  const UpdateOrderStatusHeader({
    super.key,
    required this.orderId,
    required this.onBack,
  });
  final String orderId;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              shape: const CircleBorder(),
              minimumSize: const Size(40, 40),
            ),
            icon: const Icon(Icons.chevron_left_rounded, size: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update Order Status',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                orderId,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

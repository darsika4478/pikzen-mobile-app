import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mock_order_details.dart';
import '../widgets/dashboard_surface.dart';
import '../widgets/order_details_header.dart';
import '../widgets/customer_info_section.dart';
import '../widgets/order_items_section.dart';
import '../widgets/preparation_notice.dart';
import '../widgets/order_action_bottom_bar.dart';

class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({super.key, required this.order});
  final MockOrderDetails order;

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
              OrderDetailsHeader(
                order: order,
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.goNamed('incoming-orders');
                  }
                },
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DashboardSurface(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            CustomerInfoSection(
                              order: order,
                              onCall: () => _message(context, 'Call customer'),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Divider(
                                height: 1,
                                color: AppColors.border,
                              ),
                            ),
                            OrderItemsSection(order: order),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Divider(
                                height: 1,
                                color: AppColors.border,
                              ),
                            ),
                            OrderAmountRow(total: order.total),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      PreparationNotice(deadline: order.preparationDeadline),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: OrderActionBottomBar(
      onAccept: () => _message(context, 'Order accepted'),
      onReject: () => _message(context, 'Order rejected'),
    ),
  );
}

class OrderAmountRow extends StatelessWidget {
  const OrderAmountRow({super.key, required this.total});
  final String total;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: Text(
          'Order Amount',
          style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
        ),
      ),
      const Text(
        'Total:',
        style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          total,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    ],
  );
}

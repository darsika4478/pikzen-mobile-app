import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mock_incoming_order.dart';
import '../widgets/incoming_order_card.dart';
import '../widgets/incoming_orders_header.dart';
import '../widgets/order_type_tabs.dart';

/// UI-only orders preview; no actions change or process orders.
class IncomingOrdersScreen extends StatefulWidget {
  const IncomingOrdersScreen({super.key});
  @override
  State<IncomingOrdersScreen> createState() => _IncomingOrdersScreenState();
}

class _IncomingOrdersScreenState extends State<IncomingOrdersScreen> {
  bool _scheduled = false;

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('shop-dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
                  child: IncomingOrdersHeader(
                    onBack: _back,
                    onNotifications: () =>
                        _message('No new notifications in this preview.'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OrderTypeTabs(
                    scheduled: _scheduled,
                    onChanged: (value) => setState(() => _scheduled = value),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _scheduled
                      ? const Center(
                          child: Text(
                            'No scheduled orders',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: mockIncomingOrders.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => IncomingOrderCard(
                            order: mockIncomingOrders[index],
                            onAccept: () => _message('Order accepted'),
                            onReject: () => _message('Order rejected'),
                            onDetails: () => context.pushNamed(
                              'shop-order-details',
                              pathParameters: {
                                'orderId': mockIncomingOrders[index].orderId
                                    .substring(1),
                              },
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

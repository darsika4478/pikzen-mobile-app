import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mock_order_details.dart';
import '../models/availability_item.dart';
import '../widgets/availability_product_card.dart';
import '../widgets/replacement_selector.dart';
import '../widgets/send_to_customer_bottom_bar.dart';

class ConfirmAvailabilityScreen extends StatefulWidget {
  const ConfirmAvailabilityScreen({super.key, required this.order});
  final MockOrderDetails order;
  @override
  State<ConfirmAvailabilityScreen> createState() =>
      _ConfirmAvailabilityScreenState();
}

class _ConfirmAvailabilityScreenState extends State<ConfirmAvailabilityScreen> {
  String _selectedReplacement = ReplacementSelector.options.first;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(
        'shop-order-details',
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
              ConfirmAvailabilityHeader(
                orderId: widget.order.orderId,
                onBack: _back,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'REVIEW ITEMS (${widget.order.items.length})',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: .4,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.softGreen,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Variant B: Status',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      for (
                        var index = 0;
                        index < widget.order.items.length;
                        index++
                      ) ...[
                        if (index > 0) const SizedBox(height: 11),
                        AvailabilityProductCard(
                          item: AvailabilityItem.fromOrderItem(
                            widget.order.items[index],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ReplacementSelector(
                        selected: _selectedReplacement,
                        onChanged: (value) =>
                            setState(() => _selectedReplacement = value),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: SendToCustomerBottomBar(
      onSend: () => context.pushNamed(
        'update-order-status',
        pathParameters: {'orderId': widget.order.orderId.substring(1)},
      ),
    ),
  );
}

class ConfirmAvailabilityHeader extends StatelessWidget {
  const ConfirmAvailabilityHeader({
    super.key,
    required this.orderId,
    required this.onBack,
  });
  final String orderId;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
        ),
        Expanded(
          child: Column(
            children: [
              const Text(
                'Confirm Availability',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(
                'Order $orderId',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );
}

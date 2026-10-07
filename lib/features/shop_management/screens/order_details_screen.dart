import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/order_service.dart';
import '../models/mock_order_details.dart';
import '../widgets/dashboard_surface.dart';
import '../widgets/order_details_header.dart';
import '../widgets/customer_info_section.dart';
import '../widgets/order_items_section.dart';
import '../widgets/preparation_notice.dart';
import '../widgets/order_action_bottom_bar.dart';

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, required this.order, this.orderService});
  final MockOrderDetails order;
  final OrderService? orderService;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late final OrderService _orders = widget.orderService ?? OrderService();
  bool _busy = false;

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _call() async {
    final phone = widget.order.customerPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isEmpty) {
      _message(context, 'Customer phone is unavailable for this order.');
      return;
    }
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && mounted) {
      _message(context, 'Unable to start a call to $phone.');
    }
  }

  Future<void> _reject() async {
    if (_busy || widget.order.status != 'PLACED') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Order?'),
        content: const Text('This will cancel the order for the customer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _orders.rejectShopOrder(widget.order.orderId.substring(1));
      if (!mounted) return;
      _message(context, 'Order rejected');
      context.goNamed('incoming-orders');
    } on OrderActionException catch (error) {
      if (mounted) _message(context, error.message);
    } catch (_) {
      if (mounted) {
        _message(context, 'Unable to reject this order. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
              OrderDetailsHeader(
                order: widget.order,
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
                              order: widget.order,
                              onCall: _call,
                              onContact: () {
                                ScaffoldMessenger.of(context)
                                    .removeCurrentSnackBar();
                                context.pushNamed(
                                  'contact-customer',
                                  pathParameters: {
                                    'orderId': widget.order.orderId.substring(
                                      1,
                                    ),
                                  },
                                );
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Divider(
                                height: 1,
                                color: AppColors.border,
                              ),
                            ),
                            OrderItemsSection(order: widget.order),
                            if (widget.order.customerId.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Customer ID: ${widget.order.customerId}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              Text(
                                'Payment: ${widget.order.paymentStatus}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              Text(
                                'Replacement: ${widget.order.replacementPreference}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Divider(
                                height: 1,
                                color: AppColors.border,
                              ),
                            ),
                            OrderAmountRow(total: widget.order.total),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      PreparationNotice(
                        deadline: widget.order.preparationDeadline,
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
    bottomNavigationBar: widget.order.status == 'PLACED'
        ? OrderActionBottomBar(
            onAccept: _busy
                ? null
                : () => context.pushNamed(
                    'confirm-availability',
                    pathParameters: {
                      'orderId': widget.order.orderId.substring(1),
                    },
                  ),
            onReject: _busy ? null : _reject,
          )
        : const {'ACCEPTED', 'PREPARING', 'READY'}.contains(widget.order.status)
        ? SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => context.pushNamed(
                  'update-order-status',
                  pathParameters: {
                    'orderId': widget.order.orderId.substring(1),
                  },
                ),
                child: const Text('Update Order Status'),
              ),
            ),
          )
        : null,
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

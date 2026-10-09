import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/order_service.dart';
import '../../../models/product_model.dart';
import '../models/mock_order_details.dart';
import '../models/availability_item.dart';
import '../widgets/availability_product_card.dart';
import '../widgets/send_to_customer_bottom_bar.dart';

class ConfirmAvailabilityScreen extends StatefulWidget {
  const ConfirmAvailabilityScreen({
    super.key,
    required this.order,
    this.products,
    this.orders,
  });
  final MockOrderDetails order;
  final FirestoreService? products;
  final OrderService? orders;
  @override
  State<ConfirmAvailabilityScreen> createState() =>
      _ConfirmAvailabilityScreenState();
}

class _ConfirmAvailabilityScreenState extends State<ConfirmAvailabilityScreen> {
  late final FirestoreService _products = widget.products ?? FirestoreService();
  late final OrderService _orders = widget.orders ?? OrderService();
  late final Stream<List<ProductModel>> _source = _products.shopProducts();
  bool _busy = false;

  Future<void> _accept() async {
    if (_busy || widget.order.status != 'PLACED') return;
    setState(() => _busy = true);
    try {
      final latest = await _products.currentProducts();
      final byId = {for (final product in latest) product.id: product};
      // Quantities were reserved when the customer paid; only a product the
      // shop has since removed blocks acceptance. Legacy unreserved orders
      // are stock-checked inside OrderService.updateOrderStatus.
      final unavailable = widget.order.items
          .where((item) => byId[item.productId] == null)
          .toList();
      if (unavailable.isNotEmpty) {
        throw OrderActionException(
          '${unavailable.first.name} is no longer listed by your shop.',
        );
      }
      await _orders.updateOrderStatus(
        orderId: widget.order.orderId.substring(1),
        status: 'accepted',
      );
      if (!mounted) return;
      context.goNamed(
        'update-order-status',
        pathParameters: {'orderId': widget.order.orderId.substring(1)},
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order could not be accepted: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              ConfirmAvailabilityHeader(
                orderId: widget.order.orderId,
                onBack: _back,
              ),
              Expanded(
                child: StreamBuilder<List<ProductModel>>(
                  stream: _source,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Unable to check product stock.'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final byId = {
                      for (final product in snapshot.data!) product.id: product,
                    };
                    return SingleChildScrollView(
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
                                current:
                                    byId[widget.order.items[index].productId],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Text(
                            'Customer replacement preference: ${widget.order.replacementPreference}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: SendToCustomerBottomBar(
      onSend: _busy || widget.order.status != 'PLACED' ? null : _accept,
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/order_service.dart';
import '../../../models/order_model.dart';
import '../models/mock_incoming_order.dart';
import '../widgets/incoming_order_card.dart';
import '../widgets/incoming_orders_header.dart';
import '../widgets/order_type_tabs.dart';

class IncomingOrdersScreen extends StatefulWidget {
  const IncomingOrdersScreen({super.key, this.orderService});
  final OrderService? orderService;
  @override
  State<IncomingOrdersScreen> createState() => _IncomingOrdersScreenState();
}

class _IncomingOrdersScreenState extends State<IncomingOrdersScreen> {
  bool _scheduled = false;
  String? _busyOrderId;
  late final OrderService _orders = widget.orderService ?? OrderService();
  late final Stream<List<OrderModel>> _source = _orders.forShop();

  Future<void> _reject(OrderModel order) async {
    if (_busyOrderId != null) return;
    setState(() => _busyOrderId = order.id);
    try {
      await _orders.rejectShopOrder(order.id);
      if (mounted) _message('Order rejected');
    } on OrderActionException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) _message('Unable to reject this order. Please try again.');
    } finally {
      if (mounted) setState(() => _busyOrderId = null);
    }
  }

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
                        _message('Shop notifications are not available yet.'),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<OrderModel>>(
                    stream: _source,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'Unable to load shop orders. Check your connection or approval.',
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final all = snapshot.data!;
                      final newOrders = all
                          .where((order) => order.status == 'placed')
                          .toList();
                      final visible = _scheduled
                          ? all
                                .where(
                                  (order) => const {
                                    'accepted',
                                    'preparing',
                                    'ready',
                                  }.contains(order.status),
                                )
                                .toList()
                          : newOrders;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: OrderTypeTabs(
                              scheduled: _scheduled,
                              newCount: newOrders.length,
                              onChanged: (value) =>
                                  setState(() => _scheduled = value),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: visible.isEmpty
                                ? Center(
                                    child: Text(
                                      _scheduled
                                          ? 'No scheduled orders'
                                          : 'No new orders',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      24,
                                    ),
                                    itemCount: visible.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final order = visible[index];
                                      return IncomingOrderCard(
                                        order: MockIncomingOrder.fromOrder(
                                          order,
                                        ),
                                        onAccept: () {
                                          if (_busyOrderId == null) {
                                            context.pushNamed(
                                              'confirm-availability',
                                              pathParameters: {
                                                'orderId': order.id,
                                              },
                                            );
                                          }
                                        },
                                        onReject: () => _reject(order),
                                        onDetails: () => context.pushNamed(
                                          'shop-order-details',
                                          pathParameters: {'orderId': order.id},
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
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

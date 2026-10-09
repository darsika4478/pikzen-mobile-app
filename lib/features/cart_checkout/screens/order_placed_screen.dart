import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/services/order_service.dart';
import '../../../models/cart_item_model.dart';
import '../../../models/order_model.dart';
import '../widgets/checkout_ui.dart';
import '../../../shared/widgets/animations.dart';

class OrderPlacedScreen extends StatefulWidget {
  const OrderPlacedScreen({
    super.key,
    required this.orderId,
    this.orderService,
  });
  final String? orderId;
  final OrderService? orderService;
  @override
  State<OrderPlacedScreen> createState() => _OrderPlacedScreenState();
}

class _OrderPlacedScreenState extends State<OrderPlacedScreen> {
  late final OrderService _orders = widget.orderService ?? OrderService();
  Stream<OrderModel?>? _stream;
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (widget.orderId != null &&
        (Firebase.apps.isNotEmpty || widget.orderService != null)) {
      _stream = _orders.watchOrder(widget.orderId!);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) context.goNamed('customer-home');
    },
    child: StreamBuilder<OrderModel?>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _problem('Order details are unavailable right now.');
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final order = snapshot.data;
        if (order == null) return _problem('This order could not be found.');
        if (!_recorded) {
          _recorded = true;
          _orders
              .markCustomerView(order.id, 'confirmationViewedAt')
              .catchError((Object _) {});
        }
        return _content(order);
      },
    ),
  );

  Widget _problem(String message) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(_load),
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () => context.goNamed('my-orders'),
            child: const Text('My Orders'),
          ),
        ],
      ),
    ),
  );

  Widget _content(OrderModel order) {
    final pickup = order.pickupAt;
    final id = order.id.startsWith('#') ? order.id : '#${order.id}';
    final subtotal = order.calculatedTotalMinor;
    final fee = order.effectiveTotalMinor - subtotal;
    final due = order.paymentMethod == 'cashOnPickup';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CheckoutHeader(title: 'Order Placed'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 26, 18, 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE8F3E9), Color(0xFFF8FAF8)],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      border: Border.all(
                        color: const Color(0xFFB7D4B8),
                        width: 4,
                      ),
                    ),
                    child: const PopIn(
                      child: Icon(
                        Icons.check_circle,
                        size: 42,
                        color: Color(0xFFCBF7CA),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Order Placed Successfully!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B211C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your fresh groceries are being handpicked with love by our local team.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 15,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8ECE9),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'Order ID: $id',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
              color: const Color(0xFFE9F5E9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PICKUP SCHEDULE',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: .6,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              pickup == null
                                  ? 'Pickup time unavailable'
                                  : '${shortDate(pickup)}, ${pickup.year}, ${pickupTimeLabel(pickup)}',
                              style: const TextStyle(
                                fontFamily: 'serif',
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const CircleAvatar(
                        backgroundColor: Color(0xFFD9F4DB),
                        child: Icon(
                          Icons.storefront_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.softGreen,
                          child: Image.asset(
                            AppAssets.logo,
                            width: 28,
                            height: 28,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            order.shopName?.isNotEmpty == true
                                ? order.shopName!
                                : 'PikZen pickup',
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Track order',
                          icon: const Icon(
                            Icons.directions_outlined,
                            color: AppColors.primary,
                          ),
                          onPressed: () => context.pushNamed(
                            'order-tracking',
                            extra: order.id,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Item Breakdown',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${order.items.length} items',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final item in order.items) _item(item),
                  const Divider(height: 28),
                  _totalRow(
                    'Subtotal (${order.items.length} items)',
                    rupees(subtotal),
                  ),
                  const SizedBox(height: 9),
                  _totalRow('Pickup Fee', 'FREE'),
                  if (fee != 0) ...[
                    const SizedBox(height: 9),
                    _totalRow('Service Fee', rupees(fee)),
                  ],
                  const Divider(height: 25),
                  _totalRow(
                    due ? 'Total Due' : 'Total Paid',
                    rupees(order.effectiveTotalMinor),
                    strong: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () =>
                    context.goNamed('order-details', extra: order.id),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('View Order'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF075F1A),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () => context.goNamed('customer-home'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Back to Home'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFCBF5CD),
                  foregroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required Widget child,
    Color color = const Color(0xFFF0F3F0),
  }) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );

  Widget _item(CartItemModel item) {
    final image = item.product.imageUrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 48,
              height: 48,
              child: image == null || image.isEmpty
                  ? const ColoredBox(
                      color: AppColors.softGreen,
                      child: Icon(Icons.eco_outlined, color: AppColors.primary),
                    )
                  : image.startsWith('assets/')
                  ? Image.asset(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.eco_outlined),
                    )
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.eco_outlined),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'serif', fontSize: 16),
                ),
                Text(
                  'Qty: ${item.quantity} • ${item.unit ?? (item.product.unit.isNotEmpty ? item.product.unit : '${rupees(item.product.priceMinor)} each')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            rupees(item.quantity * item.product.priceMinor),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String amount, {bool strong = false}) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: strong ? 17 : 13,
            fontWeight: strong ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'serif',
          ),
        ),
      ),
      Text(
        amount,
        style: TextStyle(
          fontSize: strong ? 17 : 13,
          fontWeight: strong ? FontWeight.bold : FontWeight.normal,
          color: strong || amount == 'FREE'
              ? AppColors.primary
              : AppColors.primaryText,
        ),
      ),
    ],
  );
}

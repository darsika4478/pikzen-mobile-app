import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/order_service.dart';
import '../../../models/order_model.dart';
import '../../../models/payment_model.dart';

class PaymentResultScreen extends StatefulWidget {
  const PaymentResultScreen({
    super.key,
    this.orderId,
    this.amountMinor,
    this.currencyCode = 'LKR',
    this.isDemo = true,
    this.order,
    this.paymentMethod = 'card',
    this.paymentStatus,
  });
  final String? orderId;
  final int? amountMinor;
  final String currencyCode;
  final bool isDemo;
  final OrderModel? order;
  final String paymentMethod;
  final String? paymentStatus;

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen> {
  final _orders = OrderService();
  Stream<OrderModel?>? _stream;
  bool _viewRecorded = false;

  @override
  void initState() {
    super.initState();
    final id = widget.orderId ?? widget.order?.id;
    if (id != null && Firebase.apps.isNotEmpty) {
      _stream = _orders.watchOrder(id);
    }
  }

  void _recordView(String id) {
    if (_viewRecorded || Firebase.apps.isEmpty) return;
    _viewRecorded = true;
    _orders
        .markCustomerView(id, 'paymentSuccessViewedAt')
        .catchError((Object _) {});
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
          return _problem('Payment information is unavailable.');
        }
        if (_stream != null &&
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final order = _stream == null ? widget.order : snapshot.data;
        if (order == null) {
          return _problem('The completed order could not be loaded.');
        }
        _recordView(order.id);
        final cash = order.paymentMethod == 'cashOnPickup';
        final id = order.id.startsWith('#') ? order.id : '#${order.id}';
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: InkWell(
              key: const Key('paymentSuccessContent'),
              onTap: () =>
                  context.goNamed('order-confirmation', extra: order.id),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFF19A75A),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: .18),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 55,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          cash ? 'Order Placed!' : 'Payment Successful!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cash
                              ? 'Payment due at pickup'
                              : 'Order placed successfully',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 72),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0C1F2937),
                                blurRadius: 18,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _row('Order ID', id),
                              const Divider(height: 30),
                              _row(
                                cash ? 'Amount Due' : 'Amount Paid',
                                formatPaymentAmount(
                                  order.effectiveTotalMinor,
                                  order.effectiveCurrencyCode,
                                ),
                              ),
                              const Divider(height: 30),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.mail_outline,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      cash
                                          ? 'Pay at the pickup counter. No charge was made.'
                                          : 'Demo payment complete. No bank charge was made.',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Tap to view your order',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
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
          if (widget.orderId != null && Firebase.apps.isNotEmpty)
            TextButton(
              onPressed: () =>
                  setState(() => _stream = _orders.watchOrder(widget.orderId!)),
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

  Widget _row(String label, String value) => Row(
    children: [
      Text(
        label,
        style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.end,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    ],
  );
}

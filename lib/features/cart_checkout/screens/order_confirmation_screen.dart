import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/order_service.dart';
import '../../../models/order_model.dart';

class OrderConfirmationScreen extends StatefulWidget {
  const OrderConfirmationScreen({super.key, this.orderDraft});

  final OrderModel? orderDraft;

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  late final Future<OrderModel?> _placement = _placeOrder();

  Future<OrderModel?> _placeOrder() {
    final draft = widget.orderDraft;
    if (draft == null) return Future.value();
    return OrderService()
        .createOrderOnce(
          draft,
          paymentMethod: 'cashOnPickup',
          paymentStatus: 'unpaid',
        )
        .catchError((_) => throw StateError('Order could not be placed.'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Order Confirmation')),
      body: SafeArea(
        child: FutureBuilder<OrderModel?>(
          future: _placement,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            final order = snapshot.data;
            if (snapshot.hasError || order == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Order details are unavailable. Return to checkout and try again.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.softGreen,
                      child: Icon(
                        Icons.check_rounded,
                        size: 54,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Order placed',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Order #${order.id}'),
                    const SizedBox(height: 5),
                    const Text('Payment due at pickup.'),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => context.goNamed('my-orders'),
                        child: const Text('View My Orders'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

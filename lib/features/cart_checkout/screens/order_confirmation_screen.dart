import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/payment_service.dart';
import '../../../models/order_model.dart';
import '../../../models/payment_model.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../payments_tracking/widgets/payment_summary_card.dart';
import '../providers/cart_provider.dart';

/// Cash is confirmed explicitly; opening this screen never saves an order.
class OrderConfirmationScreen extends StatefulWidget {
  const OrderConfirmationScreen({
    super.key,
    this.orderDraft,
    this.amountMinor,
    this.currencyCode = 'LKR',
    this.orderId,
    this.demoPayments,
  });

  final OrderModel? orderDraft;
  final int? amountMinor;
  final String currencyCode;
  final String? orderId;
  final DemoPaymentService? demoPayments;

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  bool _submitting = false;
  late final _payments = widget.demoPayments ?? DemoPaymentService();

  PaymentCheckoutData get _checkout => PaymentCheckoutData(
    amountMinor: widget.amountMinor,
    currencyCode: widget.currencyCode,
    orderId: widget.orderId,
    orderDraft: widget.orderDraft,
  );

  void _back() {
    if (_submitting) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(
        'payment-method',
        extra: _checkout.toExtra(PaymentMethod.cashOnPickup),
      );
    }
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final order = await _payments.confirm(
        _checkout,
        PaymentMethod.cashOnPickup,
      );
      if (!mounted) return;
      if (order == null) throw StateError('Order was not saved');
      context.read<CartProvider>().removePurchased(order.items);
      context.goNamed(
        'payment-result',
        extra: _checkout.successExtra(PaymentMethod.cashOnPickup, order),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The order could not be saved. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !_submitting && context.canPop(),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Order Confirmation'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _submitting ? null : _back,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    const Icon(
                      Icons.payments_outlined,
                      size: 56,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 24),
                    PaymentSummaryCard(
                      checkout: _checkout,
                      selectionLabel: 'Payment Method',
                      selection: 'Cash on Pickup',
                      amountLabel: 'Amount Due',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Pay at the pickup counter when collecting your order.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No payment is collected now.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: _submitting ? 'Confirming...' : 'Confirm Order',
                  onPressed: _submitting ? null : _confirm,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

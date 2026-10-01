import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../models/payment_model.dart';

class PaymentResultScreen extends StatelessWidget {
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

  /// Provided by order placement when it exists; this screen never creates one.
  final String? orderId;

  /// The checkout total in minor currency units, passed through the payment flow.
  final int? amountMinor;
  final String currencyCode;
  final bool isDemo;
  final OrderModel? order;
  final String paymentMethod;
  final String? paymentStatus;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final safeOrderId = (order?.id ?? orderId)?.trim();
    final hasOrderId = safeOrderId != null && safeOrderId.isNotEmpty;
    final displayOrderId = safeOrderId == null || safeOrderId.isEmpty
        ? 'Not available'
        : safeOrderId;
    final resolvedAmount = order?.effectiveTotalMinor ?? amountMinor;
    final resolvedCurrency = order?.effectiveCurrencyCode ?? currencyCode;
    final method = PaymentMethod.fromValue(
      order?.paymentMethod ?? paymentMethod,
    );
    final cash = method == PaymentMethod.cashOnPickup;
    final displayAmount = resolvedAmount == null
        ? 'Not available'
        : formatPaymentAmount(resolvedAmount, resolvedCurrency);

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.goNamed('customer-home');
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 460,
                  minHeight: MediaQuery.sizeOf(context).height * 0.72,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 64,
                        color: AppColors.surface,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      cash
                          ? (hasOrderId
                                ? 'Order placed successfully.'
                                : 'Demo order confirmed')
                          : 'Payment Successful!',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.softGreen,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        cash
                            ? 'Payment due at pickup'
                            : isDemo
                            ? 'Demo payment complete'
                            : 'Order placed successfully',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _OrderInformationCard(
                      orderId: displayOrderId,
                      amountLabel: cash ? 'Amount Due' : 'Order Total',
                      amount: displayAmount,
                      paymentMethod: method.label,
                      textTheme: textTheme,
                    ),
                    if (isDemo) ...[
                      const SizedBox(height: 14),
                      Text(
                        cash
                            ? (!hasOrderId
                                  ? 'Demo only. No order was saved and no payment was collected. Pay at the pickup counter when collecting your order.'
                                  : 'Pay at the pickup counter when collecting your order. No payment was collected now.')
                            : !hasOrderId
                            ? 'Prototype only. No real charge was processed. Checkout details were not supplied, so no order was saved.'
                            : 'Prototype only. No real charge was processed.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.goNamed('my-orders'),
                        child: const Text('View My Orders'),
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
  }
}

class _OrderInformationCard extends StatelessWidget {
  const _OrderInformationCard({
    required this.orderId,
    required this.amountLabel,
    required this.amount,
    required this.paymentMethod,
    required this.textTheme,
  });

  final String orderId;
  final String amountLabel;
  final String amount;
  final String paymentMethod;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1F2937),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _InformationRow(
            label: 'Order ID',
            value: orderId,
            textTheme: textTheme,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          _InformationRow(
            label: amountLabel,
            value: amount,
            textTheme: textTheme,
            emphasizeValue: true,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          _InformationRow(
            label: 'Payment Method',
            value: paymentMethod,
            textTheme: textTheme,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(height: 1),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.mail_outline_rounded,
                size: 19,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Email confirmation is not configured in this prototype.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.label,
    required this.value,
    required this.textTheme,
    this.emphasizeValue = false,
  });

  final String label;
  final String value;
  final TextTheme textTheme;
  final bool emphasizeValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: emphasizeValue ? FontWeight.w700 : FontWeight.w600,
              color: emphasizeValue ? AppColors.primary : AppColors.primaryText,
            ),
          ),
        ),
      ],
    );
  }
}

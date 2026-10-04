import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../models/payment_model.dart';
import '../../cart_checkout/providers/checkout_provider.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({
    super.key,
    this.amountMinor,
    this.currencyCode = 'LKR',
    this.orderId,
    this.selectedMethod = 'card',
    this.orderDraft,
  });

  final int? amountMinor;
  final String currencyCode;
  final String? orderId;
  final String selectedMethod;
  final OrderModel? orderDraft;

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  late PaymentMethod _selectedMethod;

  PaymentCheckoutData get _checkout => PaymentCheckoutData(
    amountMinor: widget.amountMinor,
    currencyCode: widget.currencyCode,
    orderId: widget.orderId,
    orderDraft: widget.orderDraft,
  );

  @override
  void initState() {
    super.initState();
    CheckoutProvider? checkout;
    try {
      checkout = context.read<CheckoutProvider>();
    } on ProviderNotFoundException {
      /* Standalone route. */
    }
    _selectedMethod =
        checkout?.paymentMethod ??
        PaymentMethod.fromValue(widget.selectedMethod);
  }

  @override
  void didUpdateWidget(covariant PaymentMethodScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMethod != widget.selectedMethod) {
      _selectedMethod = PaymentMethod.fromValue(widget.selectedMethod);
    }
  }

  void _continue() {
    CheckoutProvider? checkout;
    try {
      checkout = context.read<CheckoutProvider>();
    } on ProviderNotFoundException {
      /* Standalone route. */
    }
    if (checkout != null) {
      checkout.setPaymentMethod(_selectedMethod);
      context.goNamed('review-order');
      return;
    }
    context.pushNamed(
      _selectedMethod.routeName,
      extra: _checkout.toExtra(_selectedMethod),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('checkout');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Payment Method'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    ...PaymentMethod.values.map(
                      (method) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PaymentMethodCard(
                          method: method,
                          selected: method == _selectedMethod,
                          onTap: () => setState(() => _selectedMethod = method),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 17,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '256-bit encrypted secure checkout',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (icon, title, subtitle) = switch (method) {
      PaymentMethod.card => (
        Icons.credit_card_outlined,
        'Credit / Debit Card',
        'Recommended',
      ),
      PaymentMethod.ewallet => (
        Icons.account_balance_wallet_outlined,
        'e-Wallet',
        "Touch 'n Go, GrabPay, Boost",
      ),
      PaymentMethod.onlineBanking => (
        Icons.account_balance_outlined,
        'Online Banking',
        'FPX Direct Bank Transfer',
      ),
      PaymentMethod.cashOnPickup => (
        Icons.payments_outlined,
        'Cash on Pickup',
        'Pay counter upon collection',
      ),
    };

    return Semantics(
      selected: selected,
      button: true,
      label: '$title, $subtitle',
      child: Material(
        color: selected ? AppColors.softGreen : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 88),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.surface : AppColors.background,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: selected
                        ? AppColors.primary
                        : AppColors.secondaryText,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? AppColors.primary : AppColors.border,
                  size: 23,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

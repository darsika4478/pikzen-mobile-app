import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';

enum _PaymentMethod { card, eWallet, onlineBanking, cashOnPickup }

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
  late _PaymentMethod _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = _PaymentMethod.values.firstWhere(
      (method) => method.name == widget.selectedMethod,
      orElse: () => _PaymentMethod.card,
    );
  }

  void _continue() {
    switch (_selectedMethod) {
      case _PaymentMethod.cashOnPickup:
        context.pushNamed('order-confirmation', extra: widget.orderDraft);
        break;
      case _PaymentMethod.card:
        context.pushNamed(
          'card-payment',
          extra: {
            'amountMinor': widget.amountMinor,
            'currencyCode': widget.currencyCode,
            'orderId': widget.orderId,
            'paymentMethod': _selectedMethod.name,
            'orderDraft': widget.orderDraft,
          },
        );
        break;
      case _PaymentMethod.eWallet:
        _showUnavailableMessage('e-Wallet payment');
        break;
      case _PaymentMethod.onlineBanking:
        _showUnavailableMessage('Online banking');
        break;
    }
  }

  void _showUnavailableMessage(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature is not available yet.')));
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
                    Text(
                      'Choose how you’d like to pay',
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ..._PaymentMethod.values.map(
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
                        Text(
                          '256-bit encrypted secure checkout',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.secondaryText,
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

  final _PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (icon, title, subtitle) = switch (method) {
      _PaymentMethod.card => (
        Icons.credit_card_outlined,
        'Credit / Debit Card',
        'Recommended',
      ),
      _PaymentMethod.eWallet => (
        Icons.account_balance_wallet_outlined,
        'e-Wallet',
        'Touch ’n Go, GrabPay, Boost',
      ),
      _PaymentMethod.onlineBanking => (
        Icons.account_balance_outlined,
        'Online Banking',
        'FPX Direct Bank Transfer',
      ),
      _PaymentMethod.cashOnPickup => (
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/payment_service.dart';
import '../../../models/payment_model.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../cart_checkout/providers/cart_provider.dart';
import '../widgets/payment_summary_card.dart';

/// Dedicated wallet and bank routes share sample selection UI.
/// Selection never requests credentials or opens a provider website.
class DemoPaymentSelectionScreen extends StatefulWidget {
  const DemoPaymentSelectionScreen({
    super.key,
    required this.method,
    this.checkout = const PaymentCheckoutData(),
    this.demoPayments,
  }) : assert(
         method == PaymentMethod.ewallet ||
             method == PaymentMethod.onlineBanking,
       );

  final PaymentMethod method;
  final PaymentCheckoutData checkout;
  final DemoPaymentService? demoPayments;

  static const walletOptions = ['FriMi', 'Dialog Pay', 'eZ Cash', 'mCash'];
  static const bankOptions = [
    'Bank of Ceylon',
    "People's Bank",
    'Commercial Bank',
    'Sampath Bank',
    'HNB',
    'NDB',
  ];

  @override
  State<DemoPaymentSelectionScreen> createState() =>
      _DemoPaymentSelectionScreenState();
}

class _DemoPaymentSelectionScreenState
    extends State<DemoPaymentSelectionScreen> {
  String? _selected;
  bool _submitting = false;
  late final _payments = widget.demoPayments ?? DemoPaymentService();

  bool get _isWallet => widget.method == PaymentMethod.ewallet;
  String get _title => _isWallet ? 'Select e-Wallet' : 'Select Your Bank';
  String get _buttonLabel =>
      _isWallet ? 'Pay with e-Wallet' : 'Continue Payment';

  void _back() {
    if (_submitting) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(
        'payment-method',
        extra: widget.checkout.toExtra(widget.method),
      );
    }
  }

  Future<void> _submit() async {
    if (_selected == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final order = await _payments.confirm(widget.checkout, widget.method);
      if (!mounted) return;
      if (order == null) throw StateError('Order was not saved');
      try {
        context.read<CartProvider>().removePurchased(order.items);
      } on ProviderNotFoundException {
        // Isolated widget tests may not provide the shared cart.
      }
      context.goNamed(
        'payment-result',
        extra: widget.checkout.successExtra(widget.method, order),
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
  Widget build(BuildContext context) {
    final options = _isWallet
        ? DemoPaymentSelectionScreen.walletOptions
        : DemoPaymentSelectionScreen.bankOptions;
    return PopScope<Object?>(
      canPop: !_submitting && context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          centerTitle: true,
          title: Text(_title),
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
                      Text(
                        'Sample choices for the prototype. No money is transferred.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      for (final option in options)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _optionCard(context, option),
                        ),
                      const SizedBox(height: 6),
                      PaymentSummaryCard(
                        checkout: widget.checkout,
                        selectionLabel: _isWallet
                            ? 'Selected Wallet'
                            : 'Selected Bank',
                        selection: _selected ?? 'None selected',
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 54),
                  child: SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: _submitting ? 'Confirming...' : _buttonLabel,
                      onPressed: _selected == null || _submitting
                          ? null
                          : _submit,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionCard(BuildContext context, String option) {
    final selected = _selected == option;
    return Semantics(
      key: ValueKey(option),
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.softGreen : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _submitting ? null : () => setState(() => _selected = option),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isWallet
                      ? Icons.account_balance_wallet_outlined
                      : Icons.account_balance_outlined,
                  color: selected ? AppColors.primary : AppColors.secondaryText,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    option,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

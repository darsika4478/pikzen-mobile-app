import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../models/order_model.dart';

class PaymentFailureScreen extends StatelessWidget {
  const PaymentFailureScreen({
    super.key,
    this.paymentMethod = 'card',
    this.amountMinor,
    this.currencyCode = 'LKR',
    this.orderId,
    this.orderDraft,
  });

  /// A method identifier only; card data is never passed to this screen.
  final String paymentMethod;
  final int? amountMinor;
  final String currencyCode;

  /// Optional existing order ID. Failed attempts never create one here.
  final String? orderId;
  final OrderModel? orderDraft;

  Map<String, Object?> get _safeCheckoutData => {
    'paymentMethod': paymentMethod,
    'selectedMethod': paymentMethod,
    'amountMinor': amountMinor,
    'currencyCode': currencyCode,
    'orderId': orderId,
    'orderDraft': orderDraft,
  };

  String get _returnRoute =>
      paymentMethod == 'card' ? 'card-payment' : 'payment-method';

  void _returnToPreviousPaymentStep(BuildContext context) {
    context.goNamed(_returnRoute, extra: _safeCheckoutData);
  }

  void _tryAgain(BuildContext context) {
    context.goNamed(
      paymentMethod == 'card' ? 'card-payment' : 'payment-method',
      extra: _safeCheckoutData,
    );
  }

  void _chooseAnotherMethod(BuildContext context) {
    context.goNamed('payment-method', extra: _safeCheckoutData);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _returnToPreviousPaymentStep(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 112,
                            height: 112,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 62,
                              color: AppColors.surface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Payment Failed',
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall?.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          "We couldn't process your payment.",
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please try again or choose another method.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 36),
                        SizedBox(
                          height: 54,
                          child: PrimaryButton(
                            label: 'Try Again',
                            onPressed: () => _tryAgain(context),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            onPressed: () => _chooseAnotherMethod(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Choose Another Method'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Demo failure state — no real payment was processed.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/payment_service.dart';
import '../../../models/order_model.dart';
import '../../../models/payment_model.dart';
import '../../../shared/widgets/primary_button.dart';

class CardPaymentScreen extends StatefulWidget {
  const CardPaymentScreen({
    super.key,
    this.amountMinor,
    this.currencyCode = 'LKR',
    this.orderId,
    this.paymentMethod = 'card',
    this.orderDraft,
    this.demoPayments,
  });

  /// Optional order total in the currency's smallest unit, passed by checkout.
  final int? amountMinor;
  final String currencyCode;
  final String? orderId;
  final String paymentMethod;
  final OrderModel? orderDraft;
  final DemoPaymentService? demoPayments;

  @override
  State<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardNumberFocus = FocusNode();
  final _cardHolderFocus = FocusNode();
  final _expiryFocus = FocusNode();
  final _cvvFocus = FocusNode();
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
        extra: _checkout.toExtra(PaymentMethod.card),
      );
    }
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardNumberFocus.dispose();
    _cardHolderFocus.dispose();
    _expiryFocus.dispose();
    _cvvFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_submitting || _formKey.currentState?.validate() != true) return;

    // This project has no payment gateway. The form values remain in memory
    // only and are never sent to the order service.
    setState(() => _submitting = true);
    try {
      final order = await _payments.confirm(_checkout, PaymentMethod.card);
      if (!mounted) return;
      _cardNumberController.clear();
      _cardHolderController.clear();
      _expiryController.clear();
      _cvvController.clear();
      context.goNamed(
        'payment-result',
        extra: _checkout.successExtra(PaymentMethod.card, order),
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
    final textTheme = Theme.of(context).textTheme;

    return PopScope<Object?>(
      canPop: !_submitting && context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          centerTitle: true,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _submitting ? null : _back,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Card Payment'),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FieldLabel('CARD NUMBER', textTheme: textTheme),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _cardNumberController,
                            focusNode: _cardNumberFocus,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [],
                            inputFormatters: [
                              _CardNumberFormatter(),
                              LengthLimitingTextInputFormatter(19),
                            ],
                            decoration: _decoration(
                              hint: '1234 5678 9012 3456',
                              suffixIcon: const Icon(
                                Icons.credit_card_outlined,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            validator: _validateCardNumber,
                            onFieldSubmitted: (_) =>
                                _cardHolderFocus.requestFocus(),
                          ),
                          const SizedBox(height: 20),
                          _FieldLabel('CARD HOLDER NAME', textTheme: textTheme),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _cardHolderController,
                            focusNode: _cardHolderFocus,
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [],
                            decoration: _decoration(hint: 'John Doe'),
                            validator: _validateCardHolder,
                            onFieldSubmitted: (_) =>
                                _expiryFocus.requestFocus(),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _FieldLabel(
                                      'EXPIRY DATE',
                                      textTheme: textTheme,
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _expiryController,
                                      focusNode: _expiryFocus,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.next,
                                      inputFormatters: [_ExpiryDateFormatter()],
                                      decoration: _decoration(hint: 'MM/YY'),
                                      validator: _validateExpiry,
                                      onFieldSubmitted: (_) =>
                                          _cvvFocus.requestFocus(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _FieldLabel('CVV', textTheme: textTheme),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _cvvController,
                                      focusNode: _cvvFocus,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      obscureText: true,
                                      obscuringCharacter: '•',
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(3),
                                      ],
                                      decoration: _decoration(
                                        hint: '123',
                                        suffixIcon: const Icon(
                                          Icons.lock_outline,
                                          color: AppColors.secondaryText,
                                          size: 19,
                                        ),
                                      ),
                                      validator: _validateCvv,
                                      onFieldSubmitted: (_) => _submit(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
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
                                  'Demo payment only. No real charge is made.',
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
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: PrimaryButton(
                    label: _submitting ? 'Saving order...' : _payButtonLabel,
                    onPressed: _submitting ? null : _submit,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _payButtonLabel {
    return _checkout.totalMinor == null
        ? 'Pay'
        : 'Pay ${_checkout.amountLabel}';
  }

  static InputDecoration _decoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  static String? _validateCardNumber(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{16}$').hasMatch(digits)) {
      return 'Enter a valid card number';
    }
    return null;
  }

  static String? _validateCardHolder(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Enter the cardholder name';
    return null;
  }

  static String? _validateExpiry(String? value) {
    final match = RegExp(r'^(0[1-9]|1[0-2])/(\d{2})$').firstMatch(value ?? '');
    if (match == null) return 'Use MM/YY';
    return null;
  }

  static String? _validateCvv(String? value) {
    if (!RegExp(r'^\d{3}$').hasMatch(value ?? '')) {
      return 'Enter the 3-digit CVV';
    }
    return null;
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, {required this.textTheme});

  final String label;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: textTheme.labelMedium?.copyWith(
        color: AppColors.primaryText,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.45,
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 16 ? digits.substring(0, 16) : digits;
    final formatted = limited
        .replaceAllMapped(RegExp(r'.{1,4}'), (match) => '${match[0]} ')
        .trimRight();
    final digitsBeforeCursor = newValue.text
        .substring(
          0,
          newValue.selection.extentOffset.clamp(0, newValue.text.length),
        )
        .replaceAll(RegExp(r'\D'), '')
        .length
        .clamp(0, limited.length);
    final cursor = digitsBeforeCursor == 0
        ? 0
        : digitsBeforeCursor + ((digitsBeforeCursor - 1) ~/ 4);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: cursor.clamp(0, formatted.length),
      ),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    final formatted = limited.length <= 2
        ? limited
        : '${limited.substring(0, 2)}/${limited.substring(2)}';
    final digitsBeforeCursor = newValue.text
        .substring(
          0,
          newValue.selection.extentOffset.clamp(0, newValue.text.length),
        )
        .replaceAll(RegExp(r'\D'), '')
        .length
        .clamp(0, limited.length);
    final cursor = digitsBeforeCursor <= 2
        ? digitsBeforeCursor
        : digitsBeforeCursor + 1;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: cursor.clamp(0, formatted.length),
      ),
    );
  }
}

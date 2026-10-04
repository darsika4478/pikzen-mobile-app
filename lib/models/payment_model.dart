import 'order_model.dart';

/// Basic payment data without payment-provider integration or processing logic.
class PaymentModel {
  const PaymentModel({
    required this.id,
    required this.orderId,
    required this.amountMinor,
    required this.currencyCode,
    required this.createdAt,
  });

  final String id;
  final String orderId;

  /// Amount in the currency's smallest unit, matching ProductModel.priceMinor.
  final int amountMinor;

  /// ISO 4217 currency code, for example LKR.
  final String currencyCode;
  final DateTime createdAt;
}

/// Stable metadata and destinations for the four prototype payment methods.
enum PaymentMethod {
  card('card', 'Credit / Debit Card', 'card-payment'),
  ewallet('ewallet', 'e-Wallet', 'ewallet-payment'),
  onlineBanking('onlineBanking', 'Online Banking', 'online-banking-payment'),
  cashOnPickup('cashOnPickup', 'Cash on Pickup', 'cash-order-confirmation');

  const PaymentMethod(this.identifier, this.label, this.routeName);

  final String identifier;
  final String label;
  final String routeName;

  String get paymentStatus => this == cashOnPickup ? 'unpaid' : 'demo';

  static PaymentMethod fromValue(String? value) => switch (value) {
    'ewallet' || 'eWallet' => ewallet,
    'onlineBanking' => onlineBanking,
    'cashOnPickup' => cashOnPickup,
    _ => card,
  };
}

/// Navigation state only. Contains no card, bank or wallet credentials.
/// A supplied order draft owns its total, currency and stable document ID.
class PaymentCheckoutData {
  const PaymentCheckoutData({
    this.amountMinor,
    this.currencyCode = 'LKR',
    this.orderId,
    this.orderDraft,
  });

  final int? amountMinor;
  final String currencyCode;
  final String? orderId;
  final OrderModel? orderDraft;

  int? get totalMinor => orderDraft?.effectiveTotalMinor ?? amountMinor;
  String get currency => orderDraft?.effectiveCurrencyCode ?? currencyCode;
  String? get id => orderDraft?.id ?? orderId;
  String get amountLabel => formatPaymentAmount(totalMinor, currency);

  factory PaymentCheckoutData.fromExtra(Object? extra) {
    if (extra is PaymentCheckoutData) return extra;
    // Keep the existing cash route's OrderModel argument compatible.
    if (extra is OrderModel) return PaymentCheckoutData(orderDraft: extra);
    final args = extra is Map ? extra : const {};
    return PaymentCheckoutData(
      amountMinor: args['amountMinor'] is int
          ? args['amountMinor'] as int
          : null,
      currencyCode: args['currencyCode'] is String
          ? args['currencyCode'] as String
          : 'LKR',
      orderId: args['orderId'] is String ? args['orderId'] as String : null,
      orderDraft: args['orderDraft'] is OrderModel
          ? args['orderDraft'] as OrderModel
          : null,
    );
  }

  Map<String, Object?> toExtra(PaymentMethod method) => {
    'amountMinor': totalMinor,
    'currencyCode': currency,
    'orderId': id,
    'orderDraft': orderDraft,
    'selectedMethod': method.identifier,
    'paymentMethod': method.identifier,
  };

  Map<String, Object?> successExtra(PaymentMethod method, OrderModel? order) =>
      {
        'order': order,
        'orderId': order?.id ?? id,
        'amountMinor': order?.effectiveTotalMinor ?? totalMinor,
        'currencyCode': order?.effectiveCurrencyCode ?? currency,
        'paymentMethod': order?.paymentMethod ?? method.identifier,
        'paymentStatus': order?.paymentStatus ?? method.paymentStatus,
        'isDemo': true,
      };
}

String formatPaymentAmount(int? amountMinor, String currencyCode) {
  if (amountMinor == null) return 'Not available from checkout';
  final amount = amountMinor.abs();
  final whole = (amount ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final sign = amountMinor < 0 ? '-' : '';
  final fraction = (amount % 100).toString().padLeft(2, '0');
  return '$currencyCode $sign$whole.$fraction';
}

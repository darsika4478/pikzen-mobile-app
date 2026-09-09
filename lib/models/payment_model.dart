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

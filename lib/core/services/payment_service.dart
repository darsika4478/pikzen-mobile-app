import '../../models/order_model.dart';
import '../../models/payment_model.dart';
import 'order_service.dart';

/// Dummy card numbers for demonstrating payment outcomes. Any other 16-digit
/// number with a valid, unexpired MM/YY date is approved. Nothing is charged.
abstract final class DemoCards {
  static const approved = '4242 4242 4242 4242';
  static const declined = '4000 0000 0000 0002';
  static const insufficientFunds = '4000 0000 0000 9995';

  static String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

  /// Simulated issuer response: a decline message, or null when approved.
  static String? declineReason(String cardNumber) =>
      switch (_digits(cardNumber)) {
        final digits when digits == _digits(declined) =>
          'Your card was declined (demo test card). Try another card.',
        final digits when digits == _digits(insufficientFunds) =>
          'Insufficient funds (demo test card). Try another card.',
        _ => null,
      };

  /// True when an MM/YY expiry is before the current month.
  static bool isExpired(String expiry, {DateTime? now}) {
    final match = RegExp(r'^(0[1-9]|1[0-2])/(\d{2})$').firstMatch(expiry);
    if (match == null) return false;
    final today = now ?? DateTime.now();
    final expires = (2000 + int.parse(match[2]!)) * 12 + int.parse(match[1]!);
    return expires < today.year * 12 + today.month;
  }

  /// Only the last four digits ever leave the card form.
  static String last4(String cardNumber) {
    final digits = _digits(cardNumber);
    return digits.length < 4 ? digits : digits.substring(digits.length - 4);
  }
}

/// Simulates payment completion without contacting a payment provider.
/// Real order persistence, when checkout supplies a draft, uses OrderService.
class DemoPaymentService {
  DemoPaymentService({OrderService? orders})
    : _orders = orders ?? OrderService();

  final OrderService _orders;

  /// Explicit local simulation. No card details or bank request enter this API.
  Future<bool> processDemoPayment(PaymentCheckoutData checkout) async {
    return checkout.orderDraft != null &&
        checkout.totalMinor != null &&
        checkout.totalMinor! > 0;
  }

  Future<OrderModel?> confirm(
    PaymentCheckoutData checkout,
    PaymentMethod method, {
    DemoPaymentDetails details = const DemoPaymentDetails(),
  }) async {
    final draft = checkout.orderDraft;
    if (draft == null) return null; // UI demo only; do not invent an order.
    if (method != PaymentMethod.cashOnPickup &&
        !await processDemoPayment(checkout)) {
      throw const OrderActionException('Demo payment could not be completed.');
    }
    return _orders.createOrderOnce(
      draft,
      paymentMethod: method.identifier,
      paymentStatus: method.paymentStatus,
      paymentDetails: details,
    );
  }
}

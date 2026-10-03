import '../../models/order_model.dart';
import '../../models/payment_model.dart';
import 'order_service.dart';

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
    PaymentMethod method,
  ) async {
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
    );
  }
}

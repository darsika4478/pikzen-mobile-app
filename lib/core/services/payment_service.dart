import '../../models/order_model.dart';
import '../../models/payment_model.dart';
import 'order_service.dart';

/// Simulates payment completion without contacting a payment provider.
/// Real order persistence, when checkout supplies a draft, uses OrderService.
class DemoPaymentService {
  DemoPaymentService({OrderService? orders})
    : _orders = orders ?? OrderService();

  final OrderService _orders;

  Future<OrderModel?> confirm(
    PaymentCheckoutData checkout,
    PaymentMethod method,
  ) async {
    final draft = checkout.orderDraft;
    if (draft == null) return null; // UI demo only; do not invent an order.
    return _orders.createOrderOnce(
      draft,
      paymentMethod: method.identifier,
      paymentStatus: method.paymentStatus,
    );
  }
}

import 'mock_incoming_order.dart';
import '../../../models/order_model.dart';
import '../../../models/payment_model.dart';

enum OrderItemType { apple, banana, milk, other }

class MockOrderItem {
  const MockOrderItem({
    required this.name,
    required this.quantity,
    required this.type,
    this.productId = '',
    this.unitPriceMinor = 0,
  });
  final String name;
  final int quantity;
  final OrderItemType type;
  final String productId;
  final int unitPriceMinor;
}

class MockOrderDetails {
  const MockOrderDetails({
    required this.orderId,
    required this.customerName,
    required this.initials,
    required this.dateTime,
    required this.preparationDeadline,
    required this.total,
    required this.items,
    this.status = 'NEW',
    this.orderType = 'Pickup Request',
    this.pickupType = 'Store Pickup',
    this.customerId = '',
    this.paymentStatus = '',
    this.replacementPreference = '',
    this.acceptedAtLabel = '',
    this.customerPhone = '',
    this.pickupCode = '',
    this.arrivedAtLabel = '',
  });
  final String orderId;
  final String customerName;
  final String initials;
  final String dateTime;
  final String status;
  final String orderType;
  final String pickupType;
  final String preparationDeadline;
  final String total;
  final List<MockOrderItem> items;
  final String customerId;
  final String paymentStatus;
  final String replacementPreference;
  final String acceptedAtLabel;
  final String customerPhone;

  /// Code the customer must show at handover; empty for older orders.
  final String pickupCode;

  /// Time the customer checked in at the store; empty if not arrived.
  final String arrivedAtLabel;

  factory MockOrderDetails.fromOrder(OrderModel order) {
    final incoming = MockIncomingOrder.fromOrder(order);
    return MockOrderDetails(
      orderId: incoming.orderId,
      customerName: incoming.customerName,
      customerId: order.userId,
      customerPhone: order.customerPhone ?? '',
      pickupCode: order.pickupCode ?? '',
      arrivedAtLabel: order.arrivedAt == null
          ? ''
          : formatShopDateTime(order.arrivedAt!),
      initials: _initials(order.customerName),
      dateTime: incoming.dateTime,
      preparationDeadline: order.pickupAt == null
          ? 'Pickup time pending'
          : formatShopDateTime(
              order.pickupAt!.subtract(const Duration(minutes: 10)),
            ),
      total: formatPaymentAmount(
        order.effectiveTotalMinor,
        order.effectiveCurrencyCode,
      ),
      status: (order.status ?? 'placed').toUpperCase(),
      paymentStatus: order.paymentStatus ?? 'unknown',
      replacementPreference: order.replacementPreference ?? 'Not selected',
      acceptedAtLabel: order.acceptedAt == null
          ? 'Awaiting acceptance'
          : formatShopDateTime(order.acceptedAt!),
      items: order.items.map((item) {
        final name = item.product.name;
        final lower = name.toLowerCase();
        return MockOrderItem(
          name: name,
          quantity: item.quantity,
          productId: item.product.id,
          unitPriceMinor: item.product.priceMinor,
          type: lower.contains('banana')
              ? OrderItemType.banana
              : lower.contains('milk')
              ? OrderItemType.milk
              : lower.contains('apple')
              ? OrderItemType.apple
              : OrderItemType.other,
        );
      }).toList(),
    );
  }

  static String _initials(String? name) {
    final initials = (name ?? '')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    return initials.isEmpty ? 'C' : initials;
  }

  factory MockOrderDetails.fromIncoming(MockIncomingOrder order) {
    final second = order.orderId == '#P2002';
    final third = order.orderId == '#P2003';
    return MockOrderDetails(
      orderId: order.orderId,
      customerName: order.customerName,
      initials: order.customerName
          .split(' ')
          .where((part) => part.isNotEmpty)
          .take(2)
          .map((part) => part[0])
          .join()
          .toUpperCase(),
      dateTime: order.dateTime.replaceFirst('12 Dec,', '12 Dec 2024,'),
      preparationDeadline: second
          ? '11:20 AM'
          : third
          ? '12:50 PM'
          : '09:50 AM',
      total: order.total,
      items: [
        MockOrderItem(
          name: 'Red Apple',
          quantity: second
              ? 3
              : third
              ? 1
              : 2,
          type: OrderItemType.apple,
        ),
        MockOrderItem(
          name: 'Banana',
          quantity: second ? 2 : 1,
          type: OrderItemType.banana,
        ),
        MockOrderItem(
          name: 'Fresh Milk',
          quantity: second ? 2 : 1,
          type: OrderItemType.milk,
        ),
      ],
    );
  }
}

import 'mock_incoming_order.dart';

enum OrderItemType { apple, banana, milk }

class MockOrderItem {
  const MockOrderItem({
    required this.name,
    required this.quantity,
    required this.type,
  });
  final String name;
  final int quantity;
  final OrderItemType type;
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

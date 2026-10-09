import '../../../models/order_model.dart';
import '../../../models/payment_model.dart';

/// Display strings for the static Incoming Orders preview.
class MockIncomingOrder {
  const MockIncomingOrder({
    required this.orderId,
    required this.customerName,
    required this.timeAgo,
    required this.dateTime,
    required this.total,
    this.itemCount = 0,
  });
  final String orderId;
  final String customerName;
  final String timeAgo;
  final String dateTime;
  final String total;
  final int itemCount;

  factory MockIncomingOrder.fromOrder(OrderModel order) => MockIncomingOrder(
    orderId: '#${order.id}',
    customerName: order.customerName?.trim().isNotEmpty == true
        ? order.customerName!.trim()
        : 'Customer ${order.userId}',
    timeAgo: order.arrivedAt != null && order.status != 'collected'
        ? 'CUSTOMER ARRIVED'
        : (order.status ?? 'placed').toUpperCase(),
    dateTime: order.pickupAt == null
        ? 'Pickup time pending'
        : formatShopDateTime(order.pickupAt!),
    total: formatPaymentAmount(
      order.effectiveTotalMinor,
      order.effectiveCurrencyCode,
    ),
    itemCount: order.items.fold(0, (count, item) => count + item.quantity),
  );
}

String formatShopDateTime(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  return '${value.day} ${months[value.month - 1]} ${value.year}, '
      '$hour:${value.minute.toString().padLeft(2, '0')} '
      '${value.hour < 12 ? 'AM' : 'PM'}';
}

const mockIncomingOrders = [
  MockIncomingOrder(
    orderId: '#P2001',
    customerName: 'John Doe',
    timeAgo: 'Just Now',
    dateTime: '12 Dec, 10:00 AM',
    total: 'Rs 21.60',
  ),
  MockIncomingOrder(
    orderId: '#P2002',
    customerName: 'Jane Smith',
    timeAgo: '5 min ago',
    dateTime: '12 Dec, 11:30 AM',
    total: 'Rs 35.20',
  ),
  MockIncomingOrder(
    orderId: '#P2003',
    customerName: 'Ali Khan',
    timeAgo: '12 min ago',
    dateTime: '12 Dec, 01:00 PM',
    total: 'Rs 18.50',
  ),
];

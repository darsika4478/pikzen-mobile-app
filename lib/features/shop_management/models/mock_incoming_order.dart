/// Display strings for the static Incoming Orders preview.
class MockIncomingOrder {
  const MockIncomingOrder({
    required this.orderId,
    required this.customerName,
    required this.timeAgo,
    required this.dateTime,
    required this.total,
  });
  final String orderId;
  final String customerName;
  final String timeAgo;
  final String dateTime;
  final String total;
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

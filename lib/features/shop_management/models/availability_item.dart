import 'mock_order_details.dart';

/// Local display data only; availability is fixed for the UI preview.
class AvailabilityItem {
  const AvailabilityItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.isAvailable,
    required this.visualType,
  });
  final String name;
  final int quantity;
  final String price;
  final bool isAvailable;
  final OrderItemType visualType;

  factory AvailabilityItem.fromOrderItem(MockOrderItem item) =>
      AvailabilityItem(
        name: item.name,
        quantity: item.quantity,
        price: switch (item.type) {
          OrderItemType.apple => 'Rs 5.90',
          OrderItemType.banana => 'Rs 2.50',
          OrderItemType.milk => 'Rs 6.90',
        },
        isAvailable: item.type != OrderItemType.milk,
        visualType: item.type,
      );
}

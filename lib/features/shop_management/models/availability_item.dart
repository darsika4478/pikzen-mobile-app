import 'mock_order_details.dart';
import '../../../models/product_model.dart';
import '../../../models/payment_model.dart';

/// Display adapter for live order items and current product stock.
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

  factory AvailabilityItem.fromOrderItem(
    MockOrderItem item, {
    ProductModel? current,
  }) => AvailabilityItem(
    name: item.name,
    quantity: item.quantity,
    price: formatPaymentAmount(item.unitPriceMinor, 'LKR'),
    isAvailable:
        current != null &&
        current.isActive &&
        current.stockQuantity >= item.quantity,
    visualType: item.type,
  );
}

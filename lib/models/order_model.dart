import 'cart_item_model.dart';

/// Basic order data; lifecycle rules and totals are left to feature work.
class OrderModel {
  OrderModel({
    required this.id,
    required this.userId,
    required List<CartItemModel> items,
    required this.createdAt,
    this.pickupAt,
  }) : items = List<CartItemModel>.unmodifiable(items);

  final String id;
  final String userId;

  /// Immutable item snapshots captured when the order is created.
  final List<CartItemModel> items;
  final DateTime createdAt;
  final DateTime? pickupAt;
}

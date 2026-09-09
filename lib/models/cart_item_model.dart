import 'product_model.dart';

/// A product snapshot and its selected quantity.
class CartItemModel {
  const CartItemModel({required this.product, required this.quantity});

  final ProductModel product;
  final int quantity;
}

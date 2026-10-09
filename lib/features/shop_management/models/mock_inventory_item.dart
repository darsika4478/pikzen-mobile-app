import 'mock_shop_product.dart';
import '../../../models/product_model.dart';

/// Quantities belong to a screen visit and never modify the product catalog.
class MockInventoryItem {
  MockInventoryItem(
    this.product,
    this.unit,
    this.quantity,
    this.lowStockThreshold,
  );
  final MockShopProduct product;
  final String unit;
  int quantity;
  final int lowStockThreshold;
  bool get isLow => quantity > 0 && quantity <= lowStockThreshold;
  String get id => product.id;
  factory MockInventoryItem.fromProduct(ProductModel product) =>
      MockInventoryItem(
        MockShopProduct.fromProduct(product),
        product.unit.isEmpty ? 'unit' : product.unit,
        product.stockQuantity,
        product.lowStockThreshold,
      );
  String get status => quantity == 0
      ? 'Out of Stock'
      : isLow
      ? 'Low Stock'
      : 'In Stock';
}

List<MockInventoryItem> createMockInventory() => [
  MockInventoryItem(mockShopProducts[0], 'kg', 50, 20),
  MockInventoryItem(mockShopProducts[1], 'comb', 30, 10),
  MockInventoryItem(mockShopProducts[2], 'bottle', 20, 25),
  MockInventoryItem(mockShopProducts[3], 'loaf', 10, 5),
];

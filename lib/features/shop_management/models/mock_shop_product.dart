import '../../../models/product_model.dart';

enum ShopProductVisual { apple, banana, milk, bread }

/// Display-only products, kept separate from the live customer catalog.
class MockShopProduct {
  const MockShopProduct({
    required this.name,
    required this.price,
    required this.visualType,
    this.status = 'In Stock',
    this.category = 'Other',
    this.stockQuantity = 0,
    this.description = '',
    this.id = '',
    this.unit = '',
    this.lowStockThreshold = 5,
    this.isActive = true,
    this.imageUrl,
  });
  final String name;
  final String price;
  final String status;
  final ShopProductVisual visualType;
  final String category;
  final int stockQuantity;
  final String description;
  final String id;
  final String unit;
  final int lowStockThreshold;
  final bool isActive;
  final String? imageUrl;

  factory MockShopProduct.fromProduct(ProductModel product) {
    final lower = product.name.toLowerCase();
    final visual = lower.contains('banana')
        ? ShopProductVisual.banana
        : lower.contains('milk') || product.category == 'Dairy'
        ? ShopProductVisual.milk
        : lower.contains('bread') || product.category == 'Bakery'
        ? ShopProductVisual.bread
        : ShopProductVisual.apple;
    return MockShopProduct(
      id: product.id,
      name: product.name,
      price: product.priceLabel,
      visualType: visual,
      status: !product.isActive
          ? 'Inactive'
          : switch (product.stock) {
              StockStatus.inStock => 'In Stock',
              StockStatus.lowStock => 'Low Stock',
              StockStatus.outOfStock => 'Out of Stock',
            },
      category: product.category,
      stockQuantity: product.stockQuantity,
      description: product.description ?? '',
      unit: product.unit,
      lowStockThreshold: product.lowStockThreshold,
      isActive: product.isActive,
      imageUrl: product.imageUrl,
    );
  }
}

const mockShopProducts = [
  MockShopProduct(
    name: 'Red Apple',
    price: 'Rs 5.90',
    visualType: ShopProductVisual.apple,
    category: 'Fruits',
    stockQuantity: 50,
    description: 'Fresh and healthy red apples sourced locally.',
  ),
  MockShopProduct(
    name: 'Banana',
    price: 'Rs 2.50',
    visualType: ShopProductVisual.banana,
    category: 'Fruits',
    stockQuantity: 35,
    description: 'Fresh ripe bananas, perfect for a healthy snack.',
  ),
  MockShopProduct(
    name: 'Fresh Milk',
    price: 'Rs 6.90',
    visualType: ShopProductVisual.milk,
    category: 'Dairy',
    stockQuantity: 20,
    description: 'Fresh milk for your everyday essentials.',
  ),
  MockShopProduct(
    name: 'Bread',
    price: 'Rs 4.20',
    visualType: ShopProductVisual.bread,
    category: 'Bakery',
    stockQuantity: 25,
    description: 'Soft, freshly baked bread.',
  ),
];

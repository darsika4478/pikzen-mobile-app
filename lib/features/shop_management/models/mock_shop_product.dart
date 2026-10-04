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
  });
  final String name;
  final String price;
  final String status;
  final ShopProductVisual visualType;
  final String category;
  final int stockQuantity;
  final String description;
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

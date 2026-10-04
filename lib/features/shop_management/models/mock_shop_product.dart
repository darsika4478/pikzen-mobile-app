enum ShopProductVisual { apple, banana, milk, bread }

/// Display-only products, kept separate from the live customer catalog.
class MockShopProduct {
  const MockShopProduct({
    required this.name,
    required this.price,
    required this.visualType,
    this.status = 'In Stock',
  });
  final String name;
  final String price;
  final String status;
  final ShopProductVisual visualType;
}

const mockShopProducts = [
  MockShopProduct(
    name: 'Red Apple',
    price: 'Rs 5.90',
    visualType: ShopProductVisual.apple,
  ),
  MockShopProduct(
    name: 'Banana',
    price: 'Rs 2.50',
    visualType: ShopProductVisual.banana,
  ),
  MockShopProduct(
    name: 'Fresh Milk',
    price: 'Rs 6.90',
    visualType: ShopProductVisual.milk,
  ),
  MockShopProduct(
    name: 'Bread',
    price: 'Rs 4.20',
    visualType: ShopProductVisual.bread,
  ),
];

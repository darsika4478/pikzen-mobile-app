enum StockStatus { inStock, lowStock, outOfStock }

class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.priceMinor,
    required this.currencyCode,
    this.description,
    this.imageUrl,
    this.category = '',
    this.unit = '',
    this.stockQuantity = 99,
    this.lowStockThreshold = 5,
    this.shopId = '',
    this.shopName = '',
    this.origin = '',
    this.storage = '',
    this.packaging = '',
    this.dietary = '',
    this.brand = '',
    this.harvestLabel = '',
    this.readiness = '',
    this.rating,
    this.originalPriceMinor,
    this.isOrganic = false,
    this.isActive = true,
  });
  final String id, name, currencyCode, category, unit, shopId, shopName;
  final String origin,
      storage,
      packaging,
      dietary,
      brand,
      harvestLabel,
      readiness;
  final int priceMinor, stockQuantity, lowStockThreshold;
  final String? description, imageUrl;
  final double? rating;
  final int? originalPriceMinor;
  final bool isOrganic;
  final bool isActive;
  int get availableQuantity => stockQuantity;
  bool get onSale =>
      originalPriceMinor != null && originalPriceMinor! > priceMinor;
  StockStatus get stock => stockQuantity <= 0
      ? StockStatus.outOfStock
      : stockQuantity <= lowStockThreshold
      ? StockStatus.lowStock
      : StockStatus.inStock;
  String get priceLabel =>
      'Rs. ${(priceMinor / 100).toStringAsFixed(priceMinor % 100 == 0 ? 0 : 2)}';

  static String canonicalCategory(String value) =>
      switch (value.trim().toLowerCase()) {
        'fruits' => 'Fruits',
        'veggies' || 'vegetables' => 'Vegetables',
        'dairy' || 'dairy & eggs' => 'Dairy & Eggs',
        'bakery' => 'Bakery',
        'beverages' => 'Beverages',
        'snacks & bites' => 'Snacks & Bites',
        'household' => 'Household',
        'pantry' || 'pantry staples' => 'Pantry Staples',
        _ => value.trim(),
      };
  factory ProductModel.fromMap(String id, Map<String, dynamic> data) {
    String text(String key, [String fallback = '']) =>
        data[key] is String ? data[key] as String : fallback;
    num number(String key, [num fallback = 0]) {
      final value = data[key];
      return value is num && value.isFinite && value >= 0 ? value : fallback;
    }

    return ProductModel(
      id: id,
      name: text('name', 'Unnamed product'),
      priceMinor: data.containsKey('priceMinor')
          ? number('priceMinor').round()
          : (number('price') * 100).round(),
      currencyCode: text('currencyCode', 'LKR'),
      category: canonicalCategory(text('category')),
      unit: text('unit'),
      stockQuantity: number('stockQuantity').floor(),
      lowStockThreshold: number('lowStockThreshold', 5).floor(),
      description: text('description'),
      imageUrl: text('imageUrl', text('imagePath')),
      shopId: text('shopId'),
      shopName: text('shopName'),
      brand: text('brand'),
      origin: text('origin'),
      storage: text('storage'),
      packaging: text('packaging'),
      dietary: text('dietary'),
      harvestLabel: text('harvestLabel'),
      readiness: text('readiness'),
      rating: data['rating'] is num
          ? number('rating').clamp(0, 5).toDouble()
          : null,
      originalPriceMinor: data['originalPriceMinor'] is num
          ? number('originalPriceMinor').round()
          : null,
      isOrganic: data['isOrganic'] == true,
      isActive: data['isActive'] != false,
    );
  }
}

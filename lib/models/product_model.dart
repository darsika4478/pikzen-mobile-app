/// Basic catalog data shared by discovery, cart, and shop screens.
class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.priceMinor,
    required this.currencyCode,
    this.description,
    this.imageUrl,
  });

  final String id;
  final String name;

  /// Unit price in the currency's smallest unit, avoiding floating-point money.
  final int priceMinor;

  /// ISO 4217 currency code, for example LKR.
  final String currencyCode;
  final String? description;
  final String? imageUrl;
}

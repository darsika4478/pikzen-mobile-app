import 'package:flutter/foundation.dart';

import '../../../models/cart_item_model.dart';
import '../../../models/product_model.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItemModel> _items = {};
  String? _owner;
  Map<String, ProductModel>? _catalog;
  List<ProductModel>? _lastProducts;
  void syncProducts(List<ProductModel> products) {
    if (identical(products, _lastProducts)) return;
    _lastProducts = products;
    _catalog = {for (final product in products) product.id: product};
    var changed = false;
    for (final id in _items.keys.toList()) {
      final product = _catalog![id];
      final item = _items[id]!;
      if (product == null || product.stockQuantity <= 0) {
        _items.remove(id);
        changed = true;
      } else if (!identical(product, item.product) ||
          item.quantity > product.stockQuantity) {
        _items[id] = CartItemModel(
          product: product,
          quantity: item.quantity.clamp(0, product.stockQuantity),
        );
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void bindUser(String? uid) {
    if (_owner != uid) {
      _owner = uid;
      _items.clear();
      notifyListeners();
    }
  }

  List<CartItemModel> get items => List.unmodifiable(_items.values);
  int quantity(String id) => _items[id]?.quantity ?? 0;
  int get count => _items.values.fold(0, (sum, item) => sum + item.quantity);
  int get totalMinor => _items.values.fold(
    0,
    (sum, item) => sum + item.quantity * item.product.priceMinor,
  );
  bool add(ProductModel product) {
    if (_catalog != null) {
      final latest = _catalog![product.id];
      if (latest == null) return false;
      product = latest;
    }
    final current = quantity(product.id);
    if (product.stock == StockStatus.outOfStock ||
        current >= product.availableQuantity) {
      return false;
    }
    _items[product.id] = CartItemModel(product: product, quantity: current + 1);
    notifyListeners();
    return true;
  }

  void decrease(String id) {
    final item = _items[id];
    if (item == null) return;
    if (item.quantity <= 1) {
      _items.remove(id);
    } else {
      _items[id] = CartItemModel(
        product: item.product,
        quantity: item.quantity - 1,
      );
    }
    notifyListeners();
  }

  void remove(String id) {
    if (_items.remove(id) != null) notifyListeners();
  }
}

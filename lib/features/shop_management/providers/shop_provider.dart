import 'package:flutter/foundation.dart';

import '../../../core/services/order_service.dart';

/// Shared shop actions without a shop-specific copy of customer orders.
class ShopProvider extends ChangeNotifier {
  ShopProvider({OrderService? orders}) : _orders = orders ?? OrderService();

  final OrderService _orders;
  bool busy = false;
  String? error;

  Future<bool> updateOrderStatus(String orderId, String status) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _orders.updateOrderStatus(orderId: orderId, status: status);
      return true;
    } catch (_) {
      error = 'The order status could not be updated.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

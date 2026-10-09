import 'package:flutter/material.dart';

import '../../../models/order_model.dart';
import '../../../models/product_model.dart';
import '../../cart_checkout/providers/checkout_provider.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Tue, 12 Dec 2026".
String formatShopDay(DateTime value) =>
    '${_weekdays[value.weekday - 1]}, ${value.day} ${_months[value.month - 1]} ${value.year}';

/// "10:05 AM".
String formatShopTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
}

String greetingFor(DateTime now) => now.hour < 12
    ? 'Good Morning!'
    : now.hour < 17
    ? 'Good Afternoon!'
    : 'Good Evening!';

/// Whether customers can collect right now, from the shared pickup hours.
({bool open, String label}) storeStatusAt(DateTime now) {
  final open =
      now.hour >= PickupAvailability.openingHour &&
      now.hour < PickupAvailability.closingHour;
  final opening = formatShopTime(
    DateTime(now.year, now.month, now.day, PickupAvailability.openingHour),
  );
  return open
      ? (open: true, label: 'Online • Store Open')
      : (open: false, label: 'Store Closed • Opens $opening');
}

bool isActiveShopOrder(OrderModel order) =>
    const {'placed', 'accepted', 'preparing', 'ready'}.contains(order.status);

enum ShopAlertKind { newOrder, customerMessage, lowStock, outOfStock }

/// One actionable item for the shop's notification list.
class ShopAlert {
  const ShopAlert({
    required this.kind,
    required this.title,
    required this.message,
    this.orderId,
    this.at,
  });
  final ShopAlertKind kind;
  final String title;
  final String message;
  final String? orderId;
  final DateTime? at;

  IconData get icon => switch (kind) {
    ShopAlertKind.newOrder => Icons.shopping_bag_outlined,
    ShopAlertKind.customerMessage => Icons.chat_bubble_outline_rounded,
    ShopAlertKind.lowStock => Icons.warning_amber_rounded,
    ShopAlertKind.outOfStock => Icons.remove_shopping_cart_outlined,
  };
}

/// Alerts that need the shop's attention, most urgent first.
List<ShopAlert> shopAlerts({
  required List<OrderModel> orders,
  required List<ProductModel> products,
  required Set<String> awaitingReply,
}) {
  String label(OrderModel order) =>
      order.id.startsWith('#') ? order.id : '#${order.id}';
  String who(OrderModel order) {
    final name = order.customerName?.trim() ?? '';
    return name.isEmpty ? 'A customer' : name;
  }

  return [
    for (final order in orders.where((o) => o.status == 'placed'))
      ShopAlert(
        kind: ShopAlertKind.newOrder,
        title: 'New order ${label(order)}',
        message: order.pickupAt == null
            ? '${who(order)} ordered ${order.items.length} item(s).'
            : '${who(order)} ordered ${order.items.length} item(s) for pickup '
                  '${formatShopDay(order.pickupAt!)}, '
                  '${formatShopTime(order.pickupAt!)}.',
        orderId: order.id,
        at: order.createdAt,
      ),
    for (final order in orders.where((o) => awaitingReply.contains(o.id)))
      ShopAlert(
        kind: ShopAlertKind.customerMessage,
        title: 'Message about ${label(order)}',
        message: '${who(order)} is waiting for your reply.',
        orderId: order.id,
      ),
    for (final product in products.where(
      (p) => p.isActive && p.stock == StockStatus.outOfStock,
    ))
      ShopAlert(
        kind: ShopAlertKind.outOfStock,
        title: '${product.name} is out of stock',
        message: 'Customers cannot order it until you restock.',
      ),
    for (final product in products.where(
      (p) => p.isActive && p.stock == StockStatus.lowStock,
    ))
      ShopAlert(
        kind: ShopAlertKind.lowStock,
        title: '${product.name} is running low',
        message: 'Only ${product.stockQuantity} left in stock.',
      ),
  ];
}

/// The profile preference that switches [kind] on or off.
String shopAlertKey(ShopAlertKind kind) => switch (kind) {
  ShopAlertKind.newOrder => 'newOrderAlerts',
  ShopAlertKind.customerMessage => 'customerMessageAlerts',
  _ => 'lowStockAlerts',
};

/// Alert switches default to on; only an explicit `false` hides a kind.
bool shopAlertEnabled(Map<String, dynamic>? profile, String key) {
  final preferences = profile?['preferences'];
  return preferences is! Map || preferences[key] != false;
}

List<ShopAlert> enabledShopAlerts(
  List<ShopAlert> alerts,
  Map<String, dynamic>? profile,
) => alerts
    .where((alert) => shopAlertEnabled(profile, shopAlertKey(alert.kind)))
    .toList();

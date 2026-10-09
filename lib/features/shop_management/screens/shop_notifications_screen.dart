import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/message_service.dart';
import '../../../core/services/order_service.dart';
import '../../../models/order_model.dart';
import '../../../models/product_model.dart';
import '../models/shop_insights.dart';
import '../widgets/dashboard_surface.dart';

/// Everything that needs the shop's attention, live from orders, chats and
/// stock. Each alert type can be switched off in the settings sheet.
class ShopNotificationsScreen extends StatefulWidget {
  const ShopNotificationsScreen({
    super.key,
    this.products,
    this.orders,
    this.messages,
  });
  final FirestoreService? products;
  final OrderService? orders;
  final MessageService? messages;

  @override
  State<ShopNotificationsScreen> createState() =>
      _ShopNotificationsScreenState();
}

class _ShopNotificationsScreenState extends State<ShopNotificationsScreen> {
  late final FirestoreService _products = widget.products ?? FirestoreService();
  late final Stream<List<ProductModel>> _productStream = _products
      .shopProducts();
  late final Stream<List<OrderModel>> _orderStream =
      (widget.orders ?? OrderService()).forShop();
  late final Stream<Map<String, dynamic>> _profile = _products
      .approvedShopProfile();
  Set<String> _awaitingReply = const {};
  String _watched = '';
  StreamSubscription<Set<String>>? _replies;

  @override
  void dispose() {
    _replies?.cancel();
    super.dispose();
  }

  void _watchChats(List<OrderModel> orders) {
    final ids = orders.where(isActiveShopOrder).map((o) => o.id).toList()
      ..sort();
    final key = ids.join(',');
    if (key == _watched) return;
    _watched = key;
    _replies?.cancel();
    final service =
        widget.messages ?? (Firebase.apps.isEmpty ? null : MessageService());
    _replies = service?.awaitingReply(ids).listen((waiting) {
      if (mounted) setState(() => _awaitingReply = waiting);
    }, onError: (Object _) {});
  }

  void _open(ShopAlert alert) {
    switch (alert.kind) {
      case ShopAlertKind.newOrder:
        context.pushNamed(
          'shop-order-details',
          pathParameters: {'orderId': alert.orderId!},
        );
      case ShopAlertKind.customerMessage:
        context.pushNamed(
          'contact-customer',
          pathParameters: {'orderId': alert.orderId!},
        );
      case ShopAlertKind.lowStock || ShopAlertKind.outOfStock:
        context.pushNamed(
          'inventory-stock',
          queryParameters: const {'filter': 'low'},
        );
    }
  }

  Future<void> _settings(Map<String, dynamic>? profile) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _AlertSettingsSheet(
        initial: {
          for (final key in FirestoreService.shopAlertKeys)
            key: shopAlertEnabled(profile, key),
        },
        onChanged: _products.setShopAlert,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>>(
    stream: _profile,
    builder: (context, profileSnapshot) {
      final profile = profileSnapshot.data;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => context.canPop()
                ? context.pop()
                : context.goNamed('shop-dashboard'),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Notifications'),
          actions: [
            IconButton(
              tooltip: 'Notification settings',
              onPressed: () => _settings(profile),
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: StreamBuilder<List<ProductModel>>(
                stream: _productStream,
                builder: (context, products) => StreamBuilder<List<OrderModel>>(
                  stream: _orderStream,
                  builder: (context, orders) {
                    if (products.hasError || orders.hasError) {
                      return const Center(
                        child: Text('Notifications are unavailable right now.'),
                      );
                    }
                    if (!products.hasData || !orders.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => mounted ? _watchChats(orders.data!) : null,
                    );
                    final alerts = enabledShopAlerts(
                      shopAlerts(
                        orders: orders.data!,
                        products: products.data!,
                        awaitingReply: _awaitingReply,
                      ),
                      profile,
                    );
                    if (alerts.isEmpty) {
                      return const _AllCaughtUp();
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: alerts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _AlertTile(
                        alert: alerts[index],
                        onTap: () => _open(alerts[index]),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, required this.onTap});
  final ShopAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final warning =
        alert.kind == ShopAlertKind.lowStock ||
        alert.kind == ShopAlertKind.outOfStock;
    return DashboardSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: warning ? AppColors.lightOrange : AppColors.softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  alert.icon,
                  size: 20,
                  color: warning ? AppColors.warning : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      alert.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    if (alert.at != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${formatShopDay(alert.at!)} • ${formatShopTime(alert.at!)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllCaughtUp extends StatelessWidget {
  const _AllCaughtUp();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 48,
            color: AppColors.secondaryText,
          ),
          SizedBox(height: 12),
          Text(
            "You're all caught up",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'New orders, customer messages and stock warnings appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ],
      ),
    ),
  );
}

class _AlertSettingsSheet extends StatefulWidget {
  const _AlertSettingsSheet({required this.initial, required this.onChanged});
  final Map<String, bool> initial;
  final Future<void> Function(String key, bool enabled) onChanged;

  @override
  State<_AlertSettingsSheet> createState() => _AlertSettingsSheetState();
}

class _AlertSettingsSheetState extends State<_AlertSettingsSheet> {
  late final Map<String, bool> _values = Map.of(widget.initial);
  final Set<String> _saving = {};

  static const _labels = {
    'newOrderAlerts': ('New orders', 'When a customer places an order'),
    'customerMessageAlerts': (
      'Customer messages',
      'When a customer is waiting for a reply',
    ),
    'lowStockAlerts': ('Stock warnings', 'When a product runs low or out'),
  };

  Future<void> _toggle(String key, bool value) async {
    final previous = _values[key]!;
    setState(() {
      _values[key] = value;
      _saving.add(key);
    });
    try {
      await widget.onChanged(key, value);
    } catch (_) {
      if (mounted) {
        setState(() => _values[key] = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setting could not be saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Notification settings',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          for (final entry in _labels.entries)
            SwitchListTile(
              title: Text(entry.value.$1),
              subtitle: Text(entry.value.$2),
              value: _values[entry.key] ?? true,
              onChanged: _saving.contains(entry.key)
                  ? null
                  : (value) => _toggle(entry.key, value),
            ),
        ],
      ),
    ),
  );
}

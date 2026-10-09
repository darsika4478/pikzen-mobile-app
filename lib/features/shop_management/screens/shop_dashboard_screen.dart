import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/message_service.dart';
import '../../../core/services/order_service.dart';
import '../../../models/product_model.dart';
import '../../../models/order_model.dart';
import '../models/shop_insights.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/today_summary_card.dart';
import '../widgets/dashboard_action_card.dart';
import '../widgets/operational_checklist.dart';
import '../widgets/dashboard_bottom_nav.dart';

class ShopDashboardScreen extends StatefulWidget {
  const ShopDashboardScreen({
    super.key,
    this.products,
    this.orders,
    this.messages,
  });
  final FirestoreService? products;
  final OrderService? orders;
  final MessageService? messages;
  @override
  State<ShopDashboardScreen> createState() => _ShopDashboardScreenState();
}

class _ShopDashboardScreenState extends State<ShopDashboardScreen> {
  int _selectedIndex = 0;
  late final FirestoreService _products = widget.products ?? FirestoreService();
  late final OrderService _orders = widget.orders ?? OrderService();
  late final MessageService? _messages = widget.messages;
  late final Stream<List<ProductModel>> _productStream = _products
      .shopProducts();
  late final Stream<List<OrderModel>> _orderStream = _orders.forShop();
  late final Future<Map<String, dynamic>> _profile = _products
      .approvedShopProfile()
      .first;

  /// Active orders whose chat is waiting for the shop's reply.
  Set<String> _awaitingReply = const {};
  String _watchedOrders = '';
  StreamSubscription<Set<String>>? _replySubscription;

  @override
  void dispose() {
    _replySubscription?.cancel();
    super.dispose();
  }

  /// Re-subscribes to chats when the set of active orders changes.
  void _watchChats(List<OrderModel> orders) {
    final ids = orders.where(isActiveShopOrder).map((o) => o.id).toList()
      ..sort();
    final key = ids.join(',');
    if (key == _watchedOrders) return;
    _watchedOrders = key;
    _replySubscription?.cancel();
    final service =
        _messages ?? (Firebase.apps.isEmpty ? null : MessageService());
    if (service == null) return;
    _replySubscription = service.awaitingReply(ids).listen((waiting) {
      if (mounted) setState(() => _awaitingReply = waiting);
    }, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: StreamBuilder<List<ProductModel>>(
                stream: _productStream,
                builder: (context, productSnapshot) =>
                    StreamBuilder<List<OrderModel>>(
                      stream: _orderStream,
                      builder: (context, orderSnapshot) {
                        if (productSnapshot.hasError ||
                            orderSnapshot.hasError) {
                          return const Center(
                            child: Text(
                              'Shop data is unavailable. Check your account approval and connection.',
                            ),
                          );
                        }
                        if (!productSnapshot.hasData ||
                            !orderSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final products = productSnapshot.data!;
                        final orders = orderSnapshot.data!;
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => mounted ? _watchChats(orders) : null,
                        );
                        final newOrders = orders
                            .where((order) => order.status == 'placed')
                            .length;
                        final activeProducts = products
                            .where((product) => product.isActive)
                            .toList();
                        final lowStock = activeProducts
                            .where(
                              (product) => product.stock != StockStatus.inStock,
                            )
                            .length;
                        final alerts = shopAlerts(
                          orders: orders,
                          products: products,
                          awaitingReply: _awaitingReply,
                        );
                        final handled = orders
                            .map((order) => order.acceptedAt)
                            .whereType<DateTime>()
                            .fold<DateTime?>(
                              null,
                              (latest, at) =>
                                  latest == null || at.isAfter(latest)
                                  ? at
                                  : latest,
                            );
                        return FutureBuilder(
                          future: _profile,
                          builder: (context, profileSnapshot) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DashboardHeader(
                                shopName:
                                    (profileSnapshot.data?['shopName'] ??
                                            profileSnapshot.data?['fullName'] ??
                                            'Shop Partner')
                                        .toString(),
                                alertCount: enabledShopAlerts(
                                  alerts,
                                  profileSnapshot.data,
                                ).length,
                                onNotifications: () =>
                                    context.pushNamed('shop-notifications'),
                                onShop: () => context.pushNamed('shop-profile'),
                              ),
                              const SizedBox(height: 22),
                              TodaySummaryCard(
                                newOrders: newOrders,
                                productsListed: activeProducts.length,
                                onViewAll: () =>
                                    context.pushNamed('incoming-orders'),
                              ),
                              const SizedBox(height: 14),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: DashboardActionCard(
                                        icon: Icons.warning_amber_rounded,
                                        title: 'Low Stock',
                                        subtitle: lowStock == 0
                                            ? 'All items well stocked'
                                            : lowStock == 1
                                            ? '1 item requires attention'
                                            : '$lowStock items require attention',
                                        buttonLabel: lowStock == 0
                                            ? 'View Stock'
                                            : 'Reorder Now',
                                        isWarning: lowStock > 0,
                                        onPressed: () => context.pushNamed(
                                          'inventory-stock',
                                          queryParameters: lowStock == 0
                                              ? const {}
                                              : const {'filter': 'low'},
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DashboardActionCard(
                                        icon: Icons.bar_chart_rounded,
                                        title: 'Reports',
                                        subtitle: 'Sales & performance',
                                        buttonLabel: 'View Stats',
                                        onPressed: () =>
                                            context.pushNamed('shop-reports'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              OperationalChecklist(
                                newOrders: newOrders,
                                lowStock: lowStock,
                                unansweredQueries: _awaitingReply.length,
                                lastOrderHandledAt: handled,
                                onOrders: () =>
                                    context.pushNamed('incoming-orders'),
                                onStock: () => context.pushNamed(
                                  'inventory-stock',
                                  queryParameters: const {'filter': 'low'},
                                ),
                                onQueries: _awaitingReply.isEmpty
                                    ? null
                                    : () => context.pushNamed(
                                        'contact-customer',
                                        pathParameters: {
                                          'orderId': _awaitingReply.first,
                                        },
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: DashboardBottomNav(
        selectedIndex: _selectedIndex,
        onSelected: (index) {
          if (index == 3) {
            context.pushNamed('shop-profile');
            return;
          }
          if (index == 2) {
            context.pushNamed('product-management');
            return;
          }
          if (index == 1) {
            context.pushNamed('incoming-orders');
            return;
          }
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}

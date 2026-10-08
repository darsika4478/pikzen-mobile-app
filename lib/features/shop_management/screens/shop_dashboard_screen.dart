import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/order_service.dart';
import '../../../models/product_model.dart';
import '../../../models/order_model.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/today_summary_card.dart';
import '../widgets/dashboard_action_card.dart';
import '../widgets/operational_checklist.dart';
import '../widgets/dashboard_bottom_nav.dart';

class ShopDashboardScreen extends StatefulWidget {
  const ShopDashboardScreen({super.key, this.products, this.orders});
  final FirestoreService? products;
  final OrderService? orders;
  @override
  State<ShopDashboardScreen> createState() => _ShopDashboardScreenState();
}

class _ShopDashboardScreenState extends State<ShopDashboardScreen> {
  int _selectedIndex = 0;
  late final FirestoreService _products = widget.products ?? FirestoreService();
  late final OrderService _orders = widget.orders ?? OrderService();
  late final Stream<List<ProductModel>> _productStream = _products
      .shopProducts();
  late final Stream<List<OrderModel>> _orderStream = _orders.forShop();
  late final Future<Map<String, dynamic>> _profile = _products.approvedShopProfile().first;

  void _preview(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
            constraints: const BoxConstraints(maxWidth: 480),
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
                        final newOrders = orderSnapshot.data!
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
                        return FutureBuilder(
                          future: _profile,
                          builder: (context, profileSnapshot) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DashboardHeader(
                                shopName: (profileSnapshot.data?['shopName'] ??
                                        profileSnapshot.data?['fullName'] ??
                                        'Shop Partner')
                                    .toString(),
                                onNotifications: () => _preview(
                                  'Shop notifications are not available yet.',
                                ),
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
                                        subtitle:
                                            '$lowStock items require attention',
                                        buttonLabel: 'View Stock',
                                        isWarning: true,
                                        onPressed: () => context.pushNamed(
                                          'inventory-stock',
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
                                        onPressed: () => _preview(
                                          'Sales reports are not available yet.',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              OperationalChecklist(
                                newOrders: newOrders,
                                lowStock: lowStock,
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

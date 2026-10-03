import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/order_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/order_model.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../cart_checkout/widgets/checkout_ui.dart';

enum _OrdersFilter { all, ongoing, completed }

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key, this.orderService, this.customerId});

  final OrderService? orderService;
  final String? customerId;

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  _OrdersFilter _selectedFilter = _OrdersFilter.all;
  OrderService? _service;
  String? _streamUserId;
  Stream<List<OrderModel>>? _ordersStream;
  final Set<String> _recordedIds = {};

  void _selectFilter(_OrdersFilter filter) {
    setState(() => _selectedFilter = filter);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final profileUserId = Provider.of<AuthProvider?>(context)?.user?.id;
    final userId =
        widget.customerId ??
        (Firebase.apps.isNotEmpty
            ? FirebaseAuth.instance.currentUser?.uid
            : profileUserId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('customer-home');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('My Orders'),
        actions: [
          Tooltip(
            message: 'Past Orders',
            child: TextButton.icon(
              onPressed: () => context.pushNamed('order-history'),
              icon: const Icon(Icons.history_rounded, size: 17),
              label: const Text('Past Orders', style: TextStyle(fontSize: 10)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _selectedFilter == _OrdersFilter.all,
                    onSelected: () => _selectFilter(_OrdersFilter.all),
                    textTheme: textTheme,
                  ),
                  const SizedBox(width: 10),
                  _FilterChip(
                    label: 'Ongoing',
                    selected: _selectedFilter == _OrdersFilter.ongoing,
                    onSelected: () => _selectFilter(_OrdersFilter.ongoing),
                    textTheme: textTheme,
                  ),
                  const SizedBox(width: 10),
                  _FilterChip(
                    label: 'Completed',
                    selected: _selectedFilter == _OrdersFilter.completed,
                    onSelected: () => _selectFilter(_OrdersFilter.completed),
                    textTheme: textTheme,
                  ),
                ],
              ),
            ),
            Expanded(child: _ordersContent(context, userId)),
          ],
        ),
      ),
    );
  }

  Widget _ordersContent(BuildContext context, String? userId) {
    if (userId == null) {
      if (Firebase.apps.isNotEmpty) {
        return const Center(child: Text('Sign in to see your orders.'));
      }
      return _showOrders(context, const []);
    }
    if (Firebase.apps.isEmpty && widget.orderService == null) {
      return _showOrders(context, const []);
    }
    if (_streamUserId != userId || _ordersStream == null) {
      _streamUserId = userId;
      _recordedIds.clear();
      _service ??= widget.orderService ?? OrderService();
      _ordersStream = _service!.forCustomer(userId);
    }
    return StreamBuilder<List<OrderModel>>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Orders are unavailable right now.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final orders = (snapshot.data ?? const <OrderModel>[])
            .where((order) => order.userId == userId)
            .toList(growable: false);
        for (final order in orders) {
          if (_recordedIds.add(order.id)) {
            unawaited(
              _service!
                  .markCustomerView(order.id, 'ordersListViewedAt')
                  .catchError((Object _) {}),
            );
          }
        }
        return _showOrders(context, orders);
      },
    );
  }

  Widget _showOrders(BuildContext context, List<OrderModel> orders) {
    final visible = orders.where((order) {
      final status = order.status?.toLowerCase();
      return switch (_selectedFilter) {
        _OrdersFilter.all => true,
        _OrdersFilter.ongoing => const {
          'placed',
          'pending',
          'accepted',
          'confirmed',
          'preparing',
          'ready',
        }.contains(status),
        _OrdersFilter.completed => const {
          'collected',
          'completed',
          'cancelled',
        }.contains(status),
      };
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (visible.isEmpty) {
      return Center(
        child: EmptyState(
          title: orders.isEmpty ? 'No orders yet' : 'No orders in this filter',
          message: orders.isEmpty
              ? 'Your orders will appear here after you place one.'
              : 'Choose another order filter to see your orders.',
          icon: Icons.receipt_long_outlined,
          action: FilledButton.icon(
            onPressed: () => context.goNamed('customer-home'),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Start Shopping'),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      itemCount: visible.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final order = visible[index];
        return _MyOrderCard(
          order: order,
          onTap: () => context.pushNamed('order-details', extra: order.id),
        );
      },
    );
  }
}

class _MyOrderCard extends StatelessWidget {
  const _MyOrderCard({required this.order, required this.onTap});

  final OrderModel order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = order.createdAt;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final status = _customerStatus(order.status);
    final statusColor = switch (order.status?.toLowerCase()) {
      'cancelled' => const Color(0xFFBD1717),
      'ready' => const Color(0xFF008B60),
      'collected' || 'completed' => AppColors.secondaryText,
      _ => const Color(0xFFB26B00),
    };
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.id.startsWith('#') ? order.id : '#${order.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${date.day} ${months[date.month - 1]} ${date.year}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      rupees(order.effectiveTotalMinor),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor.withValues(alpha: .22)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _customerStatus(String? status) => switch (status?.toLowerCase()) {
  'placed' || 'pending' => 'Order Placed',
  'accepted' || 'confirmed' => 'Accepted',
  'preparing' => 'Preparing',
  'ready' => 'Ready for Pickup',
  'collected' || 'completed' => 'Collected',
  'cancelled' => 'Cancelled',
  _ => 'Status unavailable',
};

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.textTheme,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      labelStyle: textTheme.labelLarge?.copyWith(
        color: selected ? AppColors.surface : AppColors.secondaryText,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

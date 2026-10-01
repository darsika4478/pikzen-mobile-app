import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/order_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/order_model.dart';
import '../../../shared/widgets/empty_state.dart';

enum _OrdersFilter { all, ongoing, completed }

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  _OrdersFilter _selectedFilter = _OrdersFilter.all;
  OrderService? _service;
  String? _streamUserId;
  Stream<List<OrderModel>>? _ordersStream;

  void _selectFilter(_OrdersFilter filter) {
    setState(() => _selectedFilter = filter);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final userId = Provider.of<AuthProvider?>(context, listen: false)?.user?.id;

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
          IconButton(
            tooltip: 'Past Orders',
            onPressed: () => context.pushNamed('order-history'),
            icon: const Icon(Icons.history_rounded),
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
    if (userId == null || Firebase.apps.isEmpty) {
      return _showOrders(context, const []);
    }
    if (_streamUserId != userId || _ordersStream == null) {
      _streamUserId = userId;
      _service ??= OrderService();
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
        return _showOrders(context, snapshot.data ?? const []);
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
          onTap: () => context.pushNamed('order-details', extra: order),
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
    final total = order.effectiveTotalMinor;
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(order.id.startsWith('#') ? order.id : '#${order.id}'),
        subtitle: Text(_customerStatus(order.status)),
        leading: CircleAvatar(
          backgroundColor: AppColors.softGreen,
          child: const Icon(
            Icons.receipt_long_outlined,
            color: AppColors.primary,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        isThreeLine: false,
        dense: false,
        horizontalTitleGap: 12,
        titleAlignment: ListTileTitleAlignment.center,
        visualDensity: VisualDensity.standard,
        subtitleTextStyle: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.secondaryText),
        titleTextStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.primaryText,
          fontWeight: FontWeight.w700,
        ),
        // Total is appended in the trailing area so long order IDs can wrap.
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 104,
              child: Text(
                _money(total, order.effectiveCurrencyCode),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
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

String _money(int minor, String currency) {
  final amount = minor.abs();
  final whole = (amount ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '$currency ${minor < 0 ? '-' : ''}$whole.${(amount % 100).toString().padLeft(2, '0')}';
}

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

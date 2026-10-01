import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/order_model.dart';
import '../../../core/services/order_service.dart';

/// Historical orders supplied by the shared order source.
///
/// This screen deliberately does not create its own order store. The current
/// prototype has no order repository, so the app route displays the empty state
/// until an existing source supplies orders.
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({
    super.key,
    this.currentUserId,
    this.orders = const [],
    this.ordersStream,
  });

  final String? currentUserId;
  final List<OrderModel> orders;
  final Stream<List<OrderModel>>? ordersStream;

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  OrderService? _service;
  String? _streamUserId;
  Stream<List<OrderModel>>? _ordersStream;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId =
        widget.currentUserId ??
        Provider.of<AuthProvider?>(context, listen: false)?.user?.id;

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
              context.goNamed('my-orders');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Order History'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search orders...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: _buildOrders(context, userId)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrders(BuildContext context, String? userId) {
    if (widget.ordersStream == null &&
        (widget.orders.isNotEmpty || userId == null || Firebase.apps.isEmpty)) {
      return _buildOrderList(context, userId, widget.orders);
    }

    final stream = widget.ordersStream ?? _streamForUser(userId!);

    return StreamBuilder<List<OrderModel>>(
      stream: stream,
      initialData: widget.orders,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _OrderHistoryError();
        if (snapshot.connectionState == ConnectionState.waiting &&
            (snapshot.data?.isEmpty ?? true)) {
          return const _OrderHistoryLoading();
        }
        return _buildOrderList(context, userId, snapshot.data ?? const []);
      },
    );
  }

  Stream<List<OrderModel>> _streamForUser(String userId) {
    if (_streamUserId != userId || _ordersStream == null) {
      _streamUserId = userId;
      _service ??= OrderService();
      _ordersStream = _service!.forCustomer(userId);
    }
    return _ordersStream!;
  }

  Widget _buildOrderList(
    BuildContext context,
    String? userId,
    List<OrderModel> source,
  ) {
    final historicalOrders =
        userId == null
              ? <OrderModel>[]
              : source
                    .where(
                      (order) =>
                          order.userId == userId && _isHistorical(order.status),
                    )
                    .toList()
          ..sort(_newestFirst);

    if (historicalOrders.isEmpty) {
      return const _HistoryEmpty(
        title: 'No past orders yet.',
        message: 'Completed orders will appear here.',
      );
    }

    final normalizedQuery = _query.toLowerCase();
    final filteredOrders = normalizedQuery.isEmpty
        ? historicalOrders
        : historicalOrders.where((order) {
            final idMatches = order.id.toLowerCase().contains(normalizedQuery);
            final productMatches = order.items.any(
              (item) =>
                  item.product.name.toLowerCase().contains(normalizedQuery),
            );
            return idMatches || productMatches;
          }).toList();

    if (filteredOrders.isEmpty) {
      return const _HistoryEmpty(
        title: 'No matching orders found.',
        message: 'Try another order ID or product name.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      itemCount: filteredOrders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 11),
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        return _OrderHistoryCard(
          order: order,
          onTap: () => context.pushNamed('order-details', extra: order),
        );
      },
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  const _OrderHistoryCard({required this.order, required this.onTap});

  final OrderModel order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasItems = order.items.isNotEmpty;
    final totalMinor = order.items.fold<int>(
      0,
      (sum, item) => sum + item.product.priceMinor * item.quantity,
    );
    final currency = hasItems ? order.items.first.product.currencyCode : null;
    final date = order.completedAt ?? order.createdAt;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x081F2937),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _orderId(order.id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatDate(date),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  currency == null
                      ? 'Total unavailable'
                      : _formatAmount(totalMinor, currency),
                  maxLines: 2,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.chevron_right, color: AppColors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.history_rounded,
              size: 44,
              color: AppColors.primaryLight,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderHistoryLoading extends StatelessWidget {
  const _OrderHistoryLoading();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: AppColors.primary));
}

class _OrderHistoryError extends StatelessWidget {
  const _OrderHistoryError();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Text(
        'Order history is unavailable right now.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.secondaryText),
      ),
    ),
  );
}

bool _isHistorical(String? status) {
  final value = status?.trim().toLowerCase();
  return value == 'collected' || value == 'completed' || value == 'cancelled';
}

int _newestFirst(OrderModel a, OrderModel b) =>
    (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt);

String _orderId(String id) => id.startsWith('#') ? id : '#$id';

String _formatDate(DateTime value) {
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
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String _formatAmount(int amountMinor, String currencyCode) {
  final amount = amountMinor.abs();
  final whole = (amount ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final sign = amountMinor < 0 ? '-' : '';
  return '$currencyCode $sign$whole.${(amount % 100).toString().padLeft(2, '0')}';
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/order_service.dart';
import '../../../models/cart_item_model.dart';
import '../../../models/order_model.dart';
import '../../../shared/widgets/empty_state.dart';

class CustomerOrderDetailsScreen extends StatelessWidget {
  const CustomerOrderDetailsScreen({super.key, this.order, this.orderId});

  /// The selected order snapshot passed from the order list.
  final OrderModel? order;
  final String? orderId;

  @override
  Widget build(BuildContext context) {
    final selectedOrder = order;
    final selectedId = selectedOrder?.id ?? orderId;

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
        title: const Text('Order Details'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.eco_outlined, color: AppColors.primary),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: selectedId == null || Firebase.apps.isEmpty
            ? _buildBody(context, selectedOrder)
            : StreamBuilder<OrderModel?>(
                stream: OrderService().watchOrder(selectedId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Order details are unavailable right now.'),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }
                  return _buildBody(context, snapshot.data ?? selectedOrder);
                },
              ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, OrderModel? selectedOrder) {
    final textTheme = Theme.of(context).textTheme;
    return selectedOrder == null
        ? Center(
            child: EmptyState(
              title: 'Order details unavailable',
              message: orderId == null
                  ? 'Open this page from an order in My Orders.'
                  : 'Order ${_displayOrderId(orderId!)} is unavailable.',
              icon: Icons.receipt_long_outlined,
            ),
          )
        : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Tooltip(
                          message:
                              OrderService.canCustomerCancel(
                                selectedOrder.status,
                              )
                              ? 'Cancel this order'
                              : 'This order can no longer be cancelled',
                          child: TextButton.icon(
                            onPressed:
                                Firebase.apps.isNotEmpty &&
                                    OrderService.canCustomerCancel(
                                      selectedOrder.status,
                                    )
                                ? () => _confirmCancellation(
                                    context,
                                    selectedOrder,
                                  )
                                : null,
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Cancel Order'),
                            style: TextButton.styleFrom(
                              disabledForegroundColor: AppColors.error,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryText,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _displayOrderId(selectedOrder.id),
                            style: textTheme.labelLarge?.copyWith(
                              color: AppColors.surface,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DateTimeCard(order: selectedOrder),
                      const SizedBox(height: 24),
                      Text(
                        'ITEMS (${selectedOrder.items.length})',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _OrderItemsCard(items: selectedOrder.items),
                      const SizedBox(height: 18),
                      _OrderSummaryCard(order: selectedOrder),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.pushNamed(
                      'order-tracking',
                      extra: selectedOrder,
                    ),
                    icon: const Icon(Icons.location_searching_outlined),
                    label: const Text('Track Order'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
  }

  Future<void> _confirmCancellation(
    BuildContext context,
    OrderModel selectedOrder,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Order'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await OrderService().cancelOrder(selectedOrder.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This order could not be cancelled.')),
        );
      }
    }
  }

  static String _displayOrderId(String id) {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) return 'Order ID unavailable';
    return trimmedId.startsWith('#') ? trimmedId : '#$trimmedId';
  }
}

class _DateTimeCard extends StatelessWidget {
  const _DateTimeCard({required this.order});

  final OrderModel order;

  static const _months = [
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

  @override
  Widget build(BuildContext context) {
    final dateTime = order.pickupAt ?? order.createdAt;
    final date =
        '${dateTime.day} ${_months[dateTime.month - 1]} ${dateTime.year}';
    final pickupTime = order.pickupAt == null
        ? 'Not scheduled'
        : TimeOfDay.fromDateTime(order.pickupAt!).format(context);

    return _SurfaceCard(
      child: Column(
        children: [
          _DetailRow(label: 'Date', value: date),
          const SizedBox(height: 12),
          _DetailRow(label: 'Pickup Time', value: pickupTime),
        ],
      ),
    );
  }
}

class _OrderItemsCard extends StatelessWidget {
  const _OrderItemsCard({required this.items});

  final List<CartItemModel> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _SurfaceCard(
        child: Text(
          'No item details are available for this order.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
      );
    }

    return _SurfaceCard(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _ProductOrderRow(item: items[index]),
            if (index != items.length - 1) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
            ],
          ],
        ],
      ),
    );
  }
}

class _ProductOrderRow extends StatelessWidget {
  const _ProductOrderRow({required this.item});

  final CartItemModel item;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final quantity = item.quantity;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ProductThumbnail(imageUrl: product.imageUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Quantity: $quantity${item.unit == null ? '' : ' ${item.unit}'}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatAmount(product.priceMinor * quantity, product.currencyCode),
          textAlign: TextAlign.end,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: 56,
        height: 56,
        color: AppColors.softGreen,
        child: url == null || url.isEmpty
            ? const Icon(Icons.eco_outlined, color: AppColors.primary)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.eco_outlined, color: AppColors.primary),
              ),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasTotal = order.totalMinor != null || order.items.isNotEmpty;
    final totalMinor = order.effectiveTotalMinor;
    final currencyCode = order.effectiveCurrencyCode;

    return _SurfaceCard(
      child: Column(
        children: [
          _DetailRow(label: 'Payment', value: _paymentDescription(order)),
          const SizedBox(height: 12),
          _DetailRow(label: 'Status', value: _statusDescription(order.status)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                hasTotal
                    ? _formatAmount(totalMinor, currencyCode)
                    : 'Not available',
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1F2937),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

String _formatAmount(int amountMinor, String currencyCode) {
  final amount = amountMinor.abs();
  final whole = (amount ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final sign = amountMinor < 0 ? '-' : '';
  final fraction = (amount % 100).toString().padLeft(2, '0');
  return '$currencyCode $sign$whole.$fraction';
}

String _paymentDescription(OrderModel order) {
  final method = switch (order.paymentMethod) {
    'card' => 'Card',
    'eWallet' => 'e-Wallet',
    'onlineBanking' => 'Online Banking',
    'cashOnPickup' => 'Cash on Pickup',
    _ => null,
  };
  final state = switch (order.paymentStatus) {
    'paid' => 'Paid',
    'demo' => 'Demo payment',
    'unpaid' => 'Unpaid',
    'pending' => 'Pending',
    _ => null,
  };
  if (method == null && state == null) return 'Not available';
  if (method == null) return state!;
  if (state == null) return method;
  return '$state ($method)';
}

String _statusDescription(String? status) => switch (status?.toLowerCase()) {
  'placed' || 'pending' => 'Order Placed',
  'accepted' || 'confirmed' => 'Accepted',
  'preparing' => 'Preparing',
  'ready' => 'Ready for Pickup',
  'collected' || 'completed' => 'Collected',
  'cancelled' => 'Cancelled',
  _ => 'Not available',
};

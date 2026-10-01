import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/order_service.dart';
import '../../../models/order_model.dart';

/// Customer-facing tracking view for the currently selected order.
///
class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key, this.order, this.orderId});

  final OrderModel? order;

  /// ID-only routes load the same order document when Firestore is available.
  final String? orderId;

  @override
  Widget build(BuildContext context) {
    final id = (order?.id ?? orderId ?? '').trim();
    if (id.isNotEmpty && Firebase.apps.isNotEmpty) {
      return StreamBuilder<OrderModel?>(
        stream: OrderService().watchOrder(id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildScreen(context, order, error: true);
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          return _buildScreen(context, snapshot.data ?? order);
        },
      );
    }
    return _buildScreen(context, order);
  }

  Widget _buildScreen(
    BuildContext context,
    OrderModel? selectedOrder, {
    bool error = false,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back to Order Details',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('order-details', extra: selectedOrder ?? orderId);
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Track Your Order'),
        actions: [
          IconButton(
            tooltip: 'Tracking information',
            onPressed: () => _showInformation(context),
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PickupSummaryCard(order: selectedOrder, orderId: orderId),
                    const SizedBox(height: 22),
                    Text(
                      'ORDER STATUS',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (error)
                      const _TrackingUnavailable()
                    else
                      _StatusTimeline(order: selectedOrder),
                    const SizedBox(height: 20),
                    if (selectedOrder?.status?.toLowerCase() == 'cancelled')
                      const _CancelledNotice()
                    else
                      const _PickupInstructionsCard(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: selectedOrder == null && orderId == null
                          ? null
                          : () => context.pushNamed(
                              'order-details',
                              extra: selectedOrder ?? orderId,
                            ),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('View Order Details'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: null,
                    child: const Text('Need help? Contact Store'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInformation(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tracking information'),
        content: const Text(
          'Order status updates from the shared order record. Store contact details are not available yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _PickupSummaryCard extends StatelessWidget {
  const _PickupSummaryCard({required this.order, required this.orderId});

  final OrderModel? order;
  final String? orderId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pickupAt = order?.pickupAt;
    final readyTime = pickupAt == null
        ? 'Not scheduled'
        : TimeOfDay.fromDateTime(pickupAt).format(context);
    final status = _statusLabel(order?.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: .35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.eco_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 7),
              Text(
                'PIKZEN PICKUP',
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .7,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  _formatOrderId(order?.id ?? orderId ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Est. Ready',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      readyTime,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      order?.shopName ?? 'Store details unavailable',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  status,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.order});

  final OrderModel? order;

  static const _stages = [
    'Order Placed',
    'Accepted',
    'Preparing',
    'Ready for Pickup',
    'Collected',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = order?.status?.trim().toLowerCase();
    if (status == 'cancelled') return const _CancelledNotice();
    final currentIndex = _statusIndex(status);
    final collected = status == 'collected' || status == 'completed';
    final timestamps = [
      order?.createdAt,
      order?.acceptedAt,
      order?.preparingAt,
      order?.readyAt,
      order?.collectedAt ?? order?.completedAt,
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 19, 18, 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < _stages.length; index++)
            _TimelineStage(
              label: _stages[index],
              timestamp:
                  timestamps[index] == null ||
                      !(collected ||
                          index <= currentIndex ||
                          (status == null && index == 0))
                  ? null
                  : _formatTimestamp(context, timestamps[index]!),
              completed:
                  collected ||
                  index < currentIndex ||
                  (status == null && index == 0 && order != null),
              current: !collected && index == currentIndex,
              connectorCompleted: index < currentIndex || collected,
              isLast: index == _stages.length - 1,
              textTheme: textTheme,
            ),
          Padding(
            padding: const EdgeInsets.only(left: 44, bottom: 15),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                status == null
                    ? 'Current progress is unavailable'
                    : _statusLabel(status),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryText,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStage extends StatelessWidget {
  const _TimelineStage({
    required this.label,
    required this.timestamp,
    required this.completed,
    required this.current,
    required this.connectorCompleted,
    required this.isLast,
    required this.textTheme,
  });

  final String label;
  final String? timestamp;
  final bool completed;
  final bool current;
  final bool connectorCompleted;
  final bool isLast;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final color = completed || current ? AppColors.primary : AppColors.border;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: completed ? AppColors.primary : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: completed ? 1 : 2),
                  ),
                  child: completed
                      ? const Icon(Icons.check, size: 15, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      constraints: const BoxConstraints(minHeight: 34),
                      color: connectorCompleted
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.bodyMedium?.copyWith(
                      color: current
                          ? AppColors.primary
                          : completed
                          ? AppColors.primaryText
                          : AppColors.secondaryText,
                      fontWeight: completed || current
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  if (timestamp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      timestamp!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupInstructionsCard extends StatelessWidget {
  const _PickupInstructionsCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.storefront_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pickup',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Show your order number at the pickup counter.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelledNotice extends StatelessWidget {
  const _CancelledNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.error.withValues(alpha: .25)),
    ),
    child: const Row(
      children: [
        Icon(Icons.cancel_outlined, color: AppColors.error),
        SizedBox(width: 12),
        Expanded(child: Text('This order was cancelled.')),
      ],
    ),
  );
}

class _TrackingUnavailable extends StatelessWidget {
  const _TrackingUnavailable();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(16),
    child: Text(
      'Order status is unavailable right now.',
      textAlign: TextAlign.center,
    ),
  );
}

int _statusIndex(String? status) => switch (status) {
  'placed' || 'pending' => 0,
  'accepted' || 'confirmed' => 1,
  'preparing' => 2,
  'ready' => 3,
  'collected' || 'completed' => 4,
  _ => -1,
};

String _statusLabel(String? status) => switch (status?.toLowerCase()) {
  'placed' || 'pending' => 'Order Placed',
  'accepted' || 'confirmed' => 'Accepted',
  'preparing' => 'Preparing',
  'ready' => 'Ready for Pickup',
  'collected' || 'completed' => 'Collected',
  'cancelled' => 'Cancelled',
  _ => 'Status unavailable',
};

String _formatOrderId(String value) {
  if (value.isEmpty) return 'Order ID unavailable';
  return value.startsWith('#') ? value : '#$value';
}

String _formatTimestamp(BuildContext context, DateTime value) {
  final date = '${value.day} ${_month(value.month)}';
  final time = TimeOfDay.fromDateTime(value).format(context);
  return '$date, $time';
}

String _month(int month) => const [
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
][month - 1];

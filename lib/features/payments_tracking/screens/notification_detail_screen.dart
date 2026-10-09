import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/order_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/notification_model.dart';
import '../../../models/order_model.dart';

class NotificationDetailArguments {
  const NotificationDetailArguments({
    required this.notification,
    this.order,
    this.onMarkRead,
  });

  final NotificationModel notification;
  final OrderModel? order;
  final Future<void> Function(NotificationModel notification)? onMarkRead;
}

class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({
    super.key,
    this.arguments,
    this.currentUserId,
  });

  final NotificationDetailArguments? arguments;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final activeUserId =
        currentUserId ??
        Provider.of<AuthProvider?>(context, listen: false)?.user?.id;
    final notification = arguments?.notification;
    final isAuthorized =
        notification != null &&
        activeUserId != null &&
        notification.userId == activeUserId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          tooltip: 'Back to Notifications',
          onPressed: () => _returnToNotifications(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        top: false,
        child: !isAuthorized
            ? const _NotificationUnavailable()
            : _relatedOrderContent(context, arguments!),
      ),
    );
  }

  Widget _relatedOrderContent(
    BuildContext context,
    NotificationDetailArguments args,
  ) {
    final orderId = args.order?.id ?? args.notification.orderId;
    if (args.order != null || orderId == null || Firebase.apps.isEmpty) {
      return _NotificationDetailContent(
        arguments: args,
        onDismiss: () => _dismiss(context, args),
      );
    }

    return StreamBuilder<OrderModel?>(
      stream: OrderService().watchOrder(orderId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _NotificationUnavailable();
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final resolved = NotificationDetailArguments(
          notification: args.notification,
          order: snapshot.data,
          onMarkRead: args.onMarkRead,
        );
        return _NotificationDetailContent(
          arguments: resolved,
          onDismiss: () => _dismiss(context, resolved),
        );
      },
    );
  }

  Future<void> _dismiss(
    BuildContext context,
    NotificationDetailArguments args,
  ) async {
    try {
      if (!args.notification.isRead && args.onMarkRead != null) {
        await args.onMarkRead!(args.notification);
      }
      if (context.mounted) _returnToNotifications(context);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this notification.')),
        );
      }
    }
  }

  void _returnToNotifications(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('notifications');
    }
  }
}

class _NotificationDetailContent extends StatelessWidget {
  const _NotificationDetailContent({
    required this.arguments,
    required this.onDismiss,
  });

  final NotificationDetailArguments arguments;
  final VoidCallback onDismiss;

  NotificationModel get notification => arguments.notification;

  String get _type => (notification.type ?? '').trim().toLowerCase().replaceAll(
    RegExp(r'[\s-]+'),
    '_',
  );

  bool get _isOrder => const {
    'order_ready',
    'order_accepted',
    'order_rejected',
    'shop_message',
  }.contains(_type);
  bool get _isProduct => _type == 'price_update';
  bool get _isOffer => _type == 'special_offer';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final iconColor = _iconColor;
    final orderId = arguments.order?.id ?? notification.orderId;
    final pickupAt = arguments.order?.pickupAt;
    final actionAvailable =
        (_isOrder && (arguments.order != null || orderId != null)) ||
        (_isProduct && notification.productId != null);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: SizedBox(
                    width: 116,
                    height: 116,
                    child: CustomPaint(
                      painter: _DashedCirclePainter(color: iconColor),
                      child: Center(
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: .1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_icon, color: iconColor, size: 37),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  notification.title.trim().isEmpty
                      ? _fallbackTitle
                      : notification.title,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  notification.body,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.secondaryText,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 26),
                if (_isOrder) ...[
                  _InformationCard(
                    rows: [
                      _InformationRow(
                        label: 'Order ID',
                        value: orderId == null || orderId.trim().isEmpty
                            ? 'Not available'
                            : _formatOrderId(orderId),
                      ),
                      _InformationRow(
                        label: 'Pickup Time',
                        value: pickupAt == null
                            ? 'Not available'
                            : _formatDateTime(context, pickupAt),
                      ),
                      const _InformationRow(
                        label: 'Shop',
                        value: 'Not available',
                      ),
                    ],
                  ),
                  if (_type == 'order_ready') ...[
                    const SizedBox(height: 14),
                    const _NoticeBox(
                      icon: Icons.info_outline,
                      message:
                          'Please collect your order within the selected time.',
                    ),
                  ],
                ] else if (_isProduct) ...[
                  _InformationCard(
                    rows: [
                      _InformationRow(
                        label: 'Product ID',
                        value: notification.productId ?? 'Not available',
                      ),
                    ],
                  ),
                ] else if (_isOffer) ...[
                  _NoticeBox(
                    icon: Icons.card_giftcard_outlined,
                    message: notification.body,
                    color: AppColors.accent,
                  ),
                ] else ...[
                  _InformationCard(
                    rows: [
                      _InformationRow(
                        label: 'Received',
                        value: _formatDateTime(context, notification.createdAt),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: actionAvailable
                      ? () => _openDestination(context)
                      : null,
                  child: Text(_actionLabel),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: onDismiss,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String get _fallbackTitle => switch (_type) {
    'order_ready' => 'Order Ready!',
    'order_accepted' => 'Order Accepted',
    'order_rejected' => 'Order Rejected',
    'shop_message' => 'New Message',
    'price_update' => 'Price Update',
    'special_offer' => 'Special Offer',
    _ => 'Notification',
  };

  String get _actionLabel => switch (_type) {
    'shop_message' => 'Reply to Shop',
    'price_update' => 'View Product',
    'special_offer' => 'View Offer',
    _ => 'View Order',
  };

  IconData get _icon => switch (_type) {
    'order_ready' => Icons.notifications_active_outlined,
    'order_accepted' => Icons.shopping_bag_outlined,
    'order_rejected' => Icons.cancel_outlined,
    'shop_message' => Icons.chat_bubble_outline_rounded,
    'price_update' => Icons.sell_outlined,
    'special_offer' => Icons.card_giftcard_outlined,
    _ => Icons.notifications_none_rounded,
  };

  Color get _iconColor => switch (_type) {
    'order_ready' || 'order_accepted' || 'shop_message' => AppColors.primary,
    'order_rejected' => AppColors.error,
    'price_update' => AppColors.accent,
    'special_offer' => const Color(0xFFCE4778),
    _ => AppColors.primary,
  };

  void _openDestination(BuildContext context) {
    if (_type == 'shop_message' && notification.orderId != null) {
      context.pushNamed(
        'order-messages',
        extra: {
          'orderId': notification.orderId,
          'shopName': arguments.order?.shopName,
        },
      );
    } else if (_isOrder) {
      final order = arguments.order;
      final orderId = notification.orderId;
      context.pushNamed('order-details', extra: order ?? orderId);
    } else if (_isProduct) {
      context.pushNamed(
        'product-details',
        queryParameters: {'id': notification.productId!},
      );
    }
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.rows});

  final List<_InformationRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: rows[index],
            ),
            if (index != rows.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ),
        const SizedBox(width: 16),
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

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({
    required this.icon,
    required this.message,
    this.color = AppColors.accent,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.primaryText, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationUnavailable extends StatelessWidget {
  const _NotificationUnavailable();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Text(
        'This notification is unavailable for your account.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Offset.zero & size;
    const dashLength = .16;
    const gapLength = .09;
    var start = 0.0;
    while (start < math.pi * 2) {
      canvas.drawArc(rect.deflate(2), start, dashLength, false, paint);
      start += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

String _formatOrderId(String id) => id.startsWith('#') ? id : '#$id';

String _formatDateTime(BuildContext context, DateTime dateTime) {
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
  final time = TimeOfDay.fromDateTime(dateTime).format(context);
  return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}, $time';
}

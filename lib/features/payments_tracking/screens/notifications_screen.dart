import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/notification_model.dart';
import '../../../models/order_model.dart';
import 'notification_detail_screen.dart';

/// Notifications view backed by the existing display model.
///
/// A caller can provide the existing application's stream and read/navigation
/// actions when those services are available. No notification backend or local
/// read-state store is created here.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    this.currentUserId,
    this.notifications = const [],
    this.notificationStream,
    this.onMarkRead,
    this.onNotificationTap,
    this.resolveOrder,
  });

  final String? currentUserId;
  final List<NotificationModel> notifications;
  final Stream<List<NotificationModel>>? notificationStream;
  final Future<void> Function(NotificationModel notification)? onMarkRead;
  final Future<void> Function(NotificationModel notification)?
  onNotificationTap;
  final OrderModel? Function(NotificationModel notification)? resolveOrder;

  @override
  Widget build(BuildContext context) {
    final userId =
        currentUserId ??
        Provider.of<AuthProvider?>(context, listen: false)?.user?.id;
    final service = NotificationService();
    final stream =
        notificationStream ??
        (userId != null && Firebase.apps.isNotEmpty
            ? service.forUser(userId)
            : null);

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
        title: const Text('Notifications'),
      ),
      body: SafeArea(
        top: false,
        child: stream == null
            ? _buildContent(context, userId, notifications, service)
            : StreamBuilder<List<NotificationModel>>(
                stream: stream,
                initialData: notifications,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const _NotificationsError();
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      (snapshot.data?.isEmpty ?? true)) {
                    return const _NotificationsLoading();
                  }
                  return _buildContent(
                    context,
                    userId,
                    snapshot.data ?? const [],
                    service,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    String? userId,
    List<NotificationModel> source,
    NotificationService service,
  ) {
    final userNotifications =
        userId == null
              ? const <NotificationModel>[]
              : source
                    .where((notification) => notification.userId == userId)
                    .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (userNotifications.isEmpty) return const _NotificationsEmpty();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      itemCount: userNotifications.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final notification = userNotifications[index];
        return _NotificationCard(
          notification: notification,
          onTap: () => _handleTap(context, notification, service),
        );
      },
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    NotificationModel notification,
    NotificationService service,
  ) async {
    try {
      var selectedNotification = notification;
      final markReadHandler =
          onMarkRead ??
          (Firebase.apps.isNotEmpty
              ? (notification) => service.markRead(notification.id)
              : null);
      final hasReadHandler = onMarkRead != null || Firebase.apps.isNotEmpty;
      if (!notification.isRead && hasReadHandler) {
        await markReadHandler!(notification);
        selectedNotification = notification.copyWith(isRead: true);
      }
      if (onNotificationTap != null) {
        await onNotificationTap!(notification);
      } else if (context.mounted) {
        await context.pushNamed(
          'notification-details',
          extra: NotificationDetailArguments(
            notification: selectedNotification,
            order: resolveOrder?.call(selectedNotification),
            onMarkRead: markReadHandler,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this notification.')),
        );
      }
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.softGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ),
                        if (!notification.isRead) ...[
                          const SizedBox(width: 8),
                          Semantics(
                            label: 'Unread notification',
                            child: Padding(
                              padding: EdgeInsets.only(top: 5),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: SizedBox(width: 8, height: 8),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _relativeTime(notification.createdAt, DateTime.now()),
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsEmpty extends StatelessWidget {
  const _NotificationsEmpty();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.softGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No notifications yet',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Updates about your orders and PikZen will appear here.',
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

class _NotificationsLoading extends StatelessWidget {
  const _NotificationsLoading();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: AppColors.primary));
}

class _NotificationsError extends StatelessWidget {
  const _NotificationsError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: AppColors.secondaryText,
            ),
            const SizedBox(height: 12),
            Text(
              'Notifications are unavailable right now.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime createdAt, DateTime now) {
  final difference = now.difference(createdAt);
  if (difference.isNegative || difference.inSeconds < 60) return 'Just now';
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return '$minutes ${minutes == 1 ? 'min' : 'mins'} ago';
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
  }
  if (difference.inDays < 7) {
    final days = difference.inDays;
    return '$days ${days == 1 ? 'day' : 'days'} ago';
  }
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
  return '${createdAt.day} ${months[createdAt.month - 1]}';
}

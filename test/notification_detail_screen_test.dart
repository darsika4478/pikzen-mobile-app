import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/payments_tracking/screens/notification_detail_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/notifications_screen.dart';
import 'package:pikzen/models/notification_model.dart';
import 'package:pikzen/models/order_model.dart';

void main() {
  final readyNotification = NotificationModel(
    id: 'notification-7',
    userId: 'customer-1',
    title: 'Your pickup is ready',
    body: 'Order R-742 is ready for collection.',
    createdAt: DateTime(2024, 12, 12, 9),
    type: 'ORDER_READY',
    orderId: 'R-742',
  );
  final order = OrderModel(
    id: 'R-742',
    userId: 'customer-1',
    items: const [],
    createdAt: DateTime(2024, 12, 12, 9),
    pickupAt: DateTime(2024, 12, 12, 10),
  );

  testWidgets('opens dynamic order-ready detail and routes to same order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var markReadCalls = 0;
    final router = _router(
      readyNotification,
      resolveOrder: (_) => order,
      onMarkRead: (_) async {
        markReadCalls++;
      },
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.tap(find.text('Your pickup is ready'));
    await tester.pumpAndSettle();

    expect(find.text('Your pickup is ready'), findsOneWidget);
    expect(find.text('Order R-742 is ready for collection.'), findsOneWidget);
    expect(find.text('#R-742'), findsOneWidget);
    expect(find.text('12 Dec 2024, 10:00 AM'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget);
    expect(
      find.text('Please collect your order within the selected time.'),
      findsOneWidget,
    );
    expect(markReadCalls, 1);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('View Order'));
    await tester.pumpAndSettle();
    expect(find.text('Order Details for R-742'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismiss returns to Notifications and respects read state', (
    tester,
  ) async {
    var markReadCalls = 0;
    final router = _router(
      readyNotification,
      resolveOrder: (_) => order,
      onMarkRead: (_) async {
        markReadCalls++;
      },
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.tap(find.text('Your pickup is ready'));
    await tester.pumpAndSettle();
    expect(markReadCalls, 1);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Your pickup is ready'), findsOneWidget);
    expect(markReadCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'price updates open product details and offers have no fake link',
    (tester) async {
      final priceUpdate = NotificationModel(
        id: 'price-change',
        userId: 'customer-1',
        title: 'Price changed',
        body: 'A saved product price changed.',
        createdAt: DateTime(2024, 12, 12),
        type: 'PRICE_UPDATE',
        productId: 'product-91',
      );
      final router = _router(priceUpdate);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );
      await tester.tap(find.text('Price changed'));
      await tester.pumpAndSettle();
      expect(find.text('Product ID'), findsOneWidget);
      expect(find.text('product-91'), findsOneWidget);

      await tester.tap(find.byTooltip('Back to Notifications'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Price changed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Product'));
      await tester.pumpAndSettle();
      expect(find.text('Product Details for product-91'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('notification detail blocks a notification from another user', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/notification-details',
      routes: [
        GoRoute(
          path: '/notification-details',
          builder: (context, state) => NotificationDetailScreen(
            arguments: NotificationDetailArguments(
              notification: readyNotification,
            ),
            currentUserId: 'different-customer',
          ),
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          builder: (context, state) =>
              const Scaffold(body: Text('Notifications')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    expect(
      find.text('This notification is unavailable for your account.'),
      findsOneWidget,
    );
    expect(find.text('View Order'), findsNothing);
  });

  testWidgets('special offers show content without a fabricated destination', (
    tester,
  ) async {
    final offer = NotificationModel(
      id: 'offer-1',
      userId: 'customer-1',
      title: 'Fresh picks this week',
      body: 'Explore seasonal produce offers.',
      createdAt: DateTime(2024, 12, 12),
      type: 'SPECIAL_OFFER',
    );
    final router = GoRouter(
      initialLocation: '/notification-details',
      routes: [
        GoRoute(
          path: '/notification-details',
          builder: (context, state) => NotificationDetailScreen(
            arguments: NotificationDetailArguments(notification: offer),
            currentUserId: 'customer-1',
          ),
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          builder: (context, state) =>
              const Scaffold(body: Text('Notifications')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    expect(find.text('Fresh picks this week'), findsOneWidget);
    expect(find.text('Explore seasonal produce offers.'), findsNWidgets(2));
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}

GoRouter _router(
  NotificationModel notification, {
  OrderModel? Function(NotificationModel notification)? resolveOrder,
  Future<void> Function(NotificationModel notification)? onMarkRead,
}) => GoRouter(
  initialLocation: '/notifications',
  routes: [
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      builder: (context, state) => NotificationsScreen(
        currentUserId: 'customer-1',
        notifications: [notification],
        resolveOrder: resolveOrder,
        onMarkRead: onMarkRead,
      ),
    ),
    GoRoute(
      path: '/notification-details',
      name: 'notification-details',
      builder: (context, state) => NotificationDetailScreen(
        arguments: state.extra is NotificationDetailArguments
            ? state.extra as NotificationDetailArguments
            : null,
        currentUserId: 'customer-1',
      ),
    ),
    GoRoute(
      path: '/order-details',
      name: 'order-details',
      builder: (context, state) {
        final passedOrder = state.extra is OrderModel
            ? state.extra as OrderModel
            : null;
        return Scaffold(
          body: Center(
            child: Text('Order Details for ${passedOrder?.id ?? state.extra}'),
          ),
        );
      },
    ),
    GoRoute(
      path: '/product-details',
      name: 'product-details',
      builder: (context, state) => Scaffold(
        body: Text('Product Details for ${state.uri.queryParameters['id']}'),
      ),
    ),
  ],
);

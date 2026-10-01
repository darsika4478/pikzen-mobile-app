import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/payments_tracking/screens/notifications_screen.dart';
import 'package:pikzen/models/notification_model.dart';

void main() {
  testWidgets(
    'filters to the current user and shows dynamic notification data',
    (tester) async {
      var markedRead = false;
      var tapped = false;
      final notifications = [
        NotificationModel(
          id: 'for-other-user',
          userId: 'other-user',
          title: 'Private update',
          body: 'This belongs to another account.',
          createdAt: DateTime.now(),
        ),
        NotificationModel(
          id: 'customer-update',
          userId: 'customer-1',
          title: 'Order update 4821',
          body: 'Your pickup is being prepared.',
          createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
        NotificationModel(
          id: 'read-update',
          userId: 'customer-1',
          title: 'Older read update',
          body: 'This update has already been read.',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          isRead: true,
        ),
      ];

      await tester.pumpWidget(
        _app(
          NotificationsScreen(
            currentUserId: 'customer-1',
            notifications: notifications,
            onMarkRead: (notification) async => markedRead = true,
            onNotificationTap: (notification) async => tapped = true,
          ),
        ),
      );

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Order update 4821'), findsOneWidget);
      expect(find.text('Your pickup is being prepared.'), findsOneWidget);
      expect(find.text('2 mins ago'), findsOneWidget);
      expect(find.text('Older read update'), findsOneWidget);
      expect(find.text('Private update'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Unread notification',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Order update 4821'));
      await tester.pumpAndSettle();
      expect(markedRead, isTrue);
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows empty, loading, and safe error states', (tester) async {
    await tester.pumpWidget(
      _app(
        const NotificationsScreen(
          currentUserId: 'customer-1',
          notifications: [],
        ),
      ),
    );
    expect(find.text('No notifications yet'), findsOneWidget);

    final pending = StreamController<List<NotificationModel>>();
    addTearDown(pending.close);
    await tester.pumpWidget(
      _app(
        NotificationsScreen(
          currentUserId: 'customer-1',
          notificationStream: pending.stream,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final failed = StreamController<List<NotificationModel>>();
    addTearDown(failed.close);
    await tester.pumpWidget(
      _app(
        NotificationsScreen(
          currentUserId: 'customer-1',
          notificationStream: failed.stream,
        ),
      ),
    );
    failed.addError(StateError('private backend detail'));
    await tester.pump();
    expect(
      find.text('Notifications are unavailable right now.'),
      findsOneWidget,
    );
    expect(find.text('private backend detail'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child) {
  return MaterialApp(theme: AppTheme.lightTheme, home: child);
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/app.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/shop_management/models/mock_incoming_order.dart';
import 'package:pikzen/features/shop_management/models/mock_order_details.dart';
import 'package:pikzen/features/shop_management/screens/contact_customer_screen.dart';
import 'package:pikzen/features/shop_management/screens/order_details_screen.dart';
import 'package:pikzen/features/shop_management/widgets/chat_message_bubble.dart';
import 'package:pikzen/features/shop_management/widgets/message_composer.dart';

void main() {
  final order = MockOrderDetails.fromIncoming(mockIncomingOrders.first);
  for (final width in [360.0, 375.0, 390.0, 412.0, 430.0]) {
    testWidgets('Chat fits at $width px and composer moves above keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ContactCustomerScreen(order: order),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChatMessageBubble), findsNWidgets(2));
      expect(find.text('Chat with John Doe'), findsOneWidget);
      expect(find.text('TODAY 10:15 AM'), findsOneWidget);
      expect(tester.getRect(find.byType(MessageComposer)).bottom, 700);
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(MessageComposer)).bottom, 420);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: ContactCustomerScreen(order: order),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Call, attachment, send, empty input, and scroll are local', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ContactCustomerScreen(order: order),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Call John Doe'));
    await tester.pumpAndSettle();
    expect(find.text('Call John Doe'), findsOneWidget);
    await tester.tap(find.byTooltip('Attach file'));
    await tester.pumpAndSettle();
    expect(find.text('Attach file'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatMessageBubble), findsNWidgets(2));
    for (var index = 0; index < 12; index++) {
      await tester.enterText(
        find.byType(TextField),
        'Test message $index: Thank you for confirming your replacement.',
      );
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
    }
    expect(
      find.text('Test message 11: Thank you for confirming your replacement.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(scroll.pixels, closeTo(scroll.maxScrollExtent, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Customer name opens matching chat; Back preserves details and reopening resets messages',
    (tester) async {
      await tester.pumpWidget(const PikZenApp());
      appRouter.go('/shop-dashboard');
      await tester.pumpAndSettle();
      await tester.tap(find.text('View All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jane Smith'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Call customer'));
      await tester.pumpAndSettle();
      expect(find.text('Call customer'), findsOneWidget);
      await tester.tap(find.byTooltip('Contact Customer'));
      await tester.pumpAndSettle();
      expect(find.byType(ContactCustomerScreen), findsOneWidget);
      expect(find.text('Chat with Jane Smith'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Local test');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Local test'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailsScreen), findsOneWidget);
      expect(find.text('Order #P2002'), findsOneWidget);
      await tester.tap(find.byTooltip('Contact Customer'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatMessageBubble), findsNWidgets(2));
      expect(find.text('Local test'), findsNothing);
      appRouter.go('/shop-dashboard');
      await tester.pumpAndSettle();
    },
  );
}

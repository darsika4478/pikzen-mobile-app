import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/app.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/shop_management/models/mock_incoming_order.dart';
import 'package:pikzen/features/shop_management/models/mock_order_details.dart';
import 'package:pikzen/features/shop_management/screens/incoming_orders_screen.dart';
import 'package:pikzen/features/shop_management/screens/order_details_screen.dart';
import 'package:pikzen/features/shop_management/widgets/order_action_bottom_bar.dart';
import 'package:pikzen/features/shop_management/widgets/order_items_section.dart';

void main() {
  final order = MockOrderDetails.fromIncoming(mockIncomingOrders.first);
  for (final width in [360.0, 375.0, 390.0, 412.0, 430.0]) {
    testWidgets('Order details fit at $width px and actions stay fixed', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 620);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OrderDetailsScreen(order: order),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Order #P2001'), findsOneWidget);
      expect(find.text('JD'), findsOneWidget);
      expect(find.byType(OrderProductCard), findsNWidgets(3));
      expect(find.text('Rs 21.60'), findsOneWidget);
      expect(tester.getRect(find.byType(OrderActionBottomBar)).bottom, 620);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: OrderDetailsScreen(order: order),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(OrderActionBottomBar)).bottom, 620);
    });
  }

  testWidgets('Phone and bottom actions show preview SnackBars', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OrderDetailsScreen(order: order),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in ['Call customer', 'Accept Order', 'Reject Order']) {
      await tester.tap(
        label == 'Call customer' ? find.byTooltip(label) : find.text(label),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(switch (label) {
          'Accept Order' => 'Order accepted',
          'Reject Order' => 'Order rejected',
          _ => 'Call customer',
        }),
        findsOneWidget,
      );
    }
    expect(find.text('Order #P2001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Each card opens its details and Back returns to Incoming Orders',
    (tester) async {
      await tester.pumpWidget(const PikZenApp());
      appRouter.go('/shop-dashboard');
      await tester.pumpAndSettle();
      await tester.tap(find.text('View All'));
      await tester.pumpAndSettle();
      for (final incoming in mockIncomingOrders) {
        await tester.scrollUntilVisible(find.text(incoming.customerName), 120);
        await tester.tap(find.text(incoming.customerName));
        await tester.pumpAndSettle();
        expect(find.byType(OrderDetailsScreen), findsOneWidget);
        expect(find.text('Order ${incoming.orderId}'), findsOneWidget);
        expect(find.text(incoming.customerName), findsOneWidget);
        expect(find.text(incoming.total), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.byType(IncomingOrdersScreen), findsOneWidget);
      }
      await tester.scrollUntilVisible(find.text('#P2001'), -120);
      await tester.ensureVisible(find.byTooltip('View #P2001'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('View #P2001'));
      await tester.pumpAndSettle();
      expect(find.text('Order #P2001'), findsOneWidget);
      expect(tester.takeException(), isNull);
      appRouter.go('/shop-dashboard');
      await tester.pumpAndSettle();
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/app.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/shop_management/models/mock_incoming_order.dart';
import 'package:pikzen/features/shop_management/models/mock_order_details.dart';
import 'package:pikzen/features/shop_management/screens/confirm_availability_screen.dart';
import 'package:pikzen/features/shop_management/screens/order_details_screen.dart';
import 'package:pikzen/features/shop_management/widgets/availability_product_card.dart';
import 'package:pikzen/features/shop_management/widgets/send_to_customer_bottom_bar.dart';

void main() {
  final order = MockOrderDetails.fromIncoming(mockIncomingOrders.first);
  for (final width in [360.0, 375.0, 390.0, 412.0, 430.0]) {
    testWidgets('Availability fits at $width px with fixed bottom action', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final scale in [1.0, 1.3]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: ConfirmAvailabilityScreen(order: order),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AvailabilityProductCard), findsNWidgets(3));
        expect(find.text('In Stock'), findsNWidgets(2));
        expect(find.text('Not Available'), findsOneWidget);
        expect(find.text('Qty: 2 • Rs 5.90'), findsOneWidget);
        expect(
          tester.getRect(find.byType(SendToCustomerBottomBar)).bottom,
          650,
        );
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -180),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('Replacement selection remains local', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ConfirmAvailabilityScreen(order: order),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soy Milk (Rs 7.20)').last);
    await tester.pumpAndSettle();
    expect(find.text('Soy Milk (Rs 7.20)'), findsOneWidget);
    expect(find.text('Not Available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Full shop flow preserves the selected order and Back returns to details',
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
        await tester.tap(find.text('Accept Order'));
        await tester.pumpAndSettle();
        expect(find.byType(ConfirmAvailabilityScreen), findsOneWidget);
        expect(find.text('Order ${incoming.orderId}'), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.byType(OrderDetailsScreen), findsOneWidget);
        expect(find.text(incoming.customerName), findsOneWidget);
        await tester.tap(find.text('Reject Order'));
        await tester.pumpAndSettle();
        expect(find.text('Order rejected'), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      }
      appRouter.go('/shop-dashboard');
      await tester.pumpAndSettle();
    },
  );
}

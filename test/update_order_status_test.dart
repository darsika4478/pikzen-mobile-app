import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/app.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/shop_management/models/mock_incoming_order.dart';
import 'package:pikzen/features/shop_management/models/mock_order_details.dart';
import 'package:pikzen/features/shop_management/screens/confirm_availability_screen.dart';
import 'package:pikzen/features/shop_management/screens/update_order_status_screen.dart';
import 'package:pikzen/features/shop_management/widgets/order_status_bottom_bar.dart';
import 'package:pikzen/features/shop_management/widgets/order_status_timeline.dart';

void main() {
  final order = MockOrderDetails.fromIncoming(mockIncomingOrders.first);
  for (final width in [360.0, 375.0, 390.0, 412.0, 430.0]) {
    testWidgets('Status timeline fits at $width px and action stays fixed', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 620);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final scale in [1.0, 1.3]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: UpdateOrderStatusScreen(order: order),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(OrderStatusStep), findsNWidgets(4));
        expect(find.text('12 Dec, 10:05 AM'), findsOneWidget);
        expect(find.text('3 items • Rs 21.60'), findsOneWidget);
        expect(tester.getRect(find.byType(OrderStatusBottomBar)).bottom, 620);
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'Ready and Collected update the timeline locally and disable completion',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: UpdateOrderStatusScreen(order: order),
        ),
      );
      await tester.pumpAndSettle();
      List<OrderStatusStep> steps() => tester
          .widgetList<OrderStatusStep>(find.byType(OrderStatusStep))
          .toList();
      expect(steps().map((step) => step.completed), [
        true,
        false,
        false,
        false,
      ]);
      expect(steps()[1].active, isTrue);
      await tester.tap(find.text('Mark as Ready'));
      await tester.pumpAndSettle();
      expect(steps().map((step) => step.completed), [true, true, false, false]);
      expect(steps()[2].active, isTrue);
      await tester.tap(find.text('Mark as Collected'));
      await tester.pumpAndSettle();
      expect(steps().every((step) => step.completed), isTrue);
      expect(steps().every((step) => !step.active), isTrue);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Order Completed'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Full flow preserves selected order and replacement on Back; progress resets on reopen',
    (tester) async {
      await tester.pumpWidget(const PikZenApp());
      appRouter.go('/shop-dashboard');
      await tester.pumpAndSettle();
      await tester.tap(find.text('View All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jane Smith'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept Order'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oat Milk (Rs 8.00)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send to Customer'));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateOrderStatusScreen), findsOneWidget);
      expect(find.text('#P2002'), findsOneWidget);
      expect(find.text('Customer: Jane Smith'), findsOneWidget);
      await tester.tap(find.text('Mark as Ready'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmAvailabilityScreen), findsOneWidget);
      expect(find.text('Oat Milk (Rs 8.00)'), findsOneWidget);
      await tester.tap(find.text('Send to Customer'));
      await tester.pumpAndSettle();
      expect(find.text('Mark as Ready'), findsOneWidget);
      appRouter.go('/shop-dashboard');
      await tester.pumpAndSettle();
    },
  );
}

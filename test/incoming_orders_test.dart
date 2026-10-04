import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/app.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/shop_management/screens/incoming_orders_screen.dart';
import 'package:pikzen/features/shop_management/screens/shop_dashboard_screen.dart';
import 'package:pikzen/features/shop_management/widgets/incoming_order_card.dart';

void main() {
  for (final width in [360.0, 375.0, 390.0, 412.0, 430.0]) {
    testWidgets('Incoming orders fit and scroll at $width px', (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const IncomingOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('#P2001'), findsOneWidget);
      expect(find.text('Rs 21.60'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Ali Khan'), 180);
      await tester.pumpAndSettle();
      expect(find.text('Rs 18.50'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: IncomingOrdersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Tabs and order actions provide local feedback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const IncomingOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept').first);
    await tester.pumpAndSettle();
    expect(find.text('Order accepted'), findsOneWidget);
    await tester.tap(find.text('Reject').first);
    await tester.pumpAndSettle();
    expect(find.text('Order rejected'), findsOneWidget);
    expect(find.text('#P2001'), findsOneWidget);
    await tester.tap(find.text('Scheduled'));
    await tester.pumpAndSettle();
    expect(find.text('No scheduled orders'), findsOneWidget);
    expect(find.byType(IncomingOrderCard), findsNothing);
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(find.text('#P2001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dashboard View All and Orders open orders and Back returns', (
    tester,
  ) async {
    await tester.pumpWidget(const PikZenApp());
    appRouter.go('/shop-dashboard');
    await tester.pumpAndSettle();
    for (final label in ['View All', 'Orders']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(IncomingOrdersScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(ShopDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

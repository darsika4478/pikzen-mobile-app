import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/payments_tracking/screens/my_orders_screen.dart';

void main() {
  testWidgets(
    'shows the empty state and keeps filters and Past Orders usable',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/my-orders',
        routes: [
          GoRoute(
            path: '/my-orders',
            name: 'my-orders',
            builder: (context, state) => const MyOrdersScreen(),
          ),
          GoRoute(
            path: '/customer-home',
            name: 'customer-home',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Customer Home'))),
          ),
          GoRoute(
            path: '/order-history',
            name: 'order-history',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Order History'))),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );

      expect(find.text('My Orders'), findsOneWidget);
      expect(find.text('No orders yet'), findsOneWidget);
      expect(find.text('Start Shopping'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All'))
            .selected,
        isTrue,
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Ongoing'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Ongoing'))
            .selected,
        isTrue,
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Completed'))
            .selected,
        isTrue,
      );

      await tester.tap(find.byTooltip('Past Orders'));
      await tester.pumpAndSettle();
      expect(find.text('Order History'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('My Orders'), findsOneWidget);

      await tester.tap(find.text('Start Shopping'));
      await tester.pumpAndSettle();
      expect(find.text('Customer Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

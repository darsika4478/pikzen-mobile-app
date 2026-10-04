import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/app.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/profile/screens/profile_screen.dart';
import 'package:pikzen/features/shop_management/screens/incoming_orders_screen.dart';
import 'package:pikzen/features/shop_management/screens/product_management_screen.dart';
import 'package:pikzen/features/shop_management/screens/shop_dashboard_screen.dart';
import 'package:pikzen/features/shop_management/widgets/dashboard_bottom_nav.dart';
import 'package:pikzen/features/shop_management/widgets/product_list_card.dart';
import 'package:pikzen/features/shop_management/widgets/products_header.dart';

void main() {
  for (final width in [360.0, 375.0, 390.0, 412.0, 430.0]) {
    testWidgets('Products fit at $width px and keep navigation fixed', (
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
              child: const ProductsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProductListCard), findsNWidgets(4));
        expect(find.text('In Stock'), findsNWidgets(4));
        expect(
          tester
              .widget<DashboardBottomNav>(find.byType(DashboardBottomNav))
              .selectedIndex,
          2,
        );
        expect(tester.getRect(find.byType(DashboardBottomNav)).bottom, 650);
        final title = find.descendant(
          of: find.byType(ProductsHeader),
          matching: find.text('Products'),
        );
        expect(tester.getCenter(title).dx, closeTo(width / 2, 1));
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView), const Offset(0, -150));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('Local search, product selection, and Add button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const ProductsScreen()),
    );
    await tester.pumpAndSettle();
    for (final (query, result) in [
      ('Apple', 'Red Apple'),
      ('mILK', 'Fresh Milk'),
    ]) {
      await tester.enterText(find.byType(TextField), query);
      await tester.pumpAndSettle();
      expect(find.byType(ProductListCard), findsOneWidget);
      expect(find.text(result), findsOneWidget);
      await tester.tap(find.text(result));
      await tester.pumpAndSettle();
      expect(find.text('$result selected'), findsOneWidget);
    }
    await tester.enterText(find.byType(TextField), 'no match');
    await tester.pumpAndSettle();
    expect(find.text('No products found'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.byType(ProductListCard), findsNWidgets(4));
    await tester.tap(find.byTooltip('Add Product'));
    await tester.pumpAndSettle();
    expect(find.text('Add Product'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dashboard Products, Back, and all product navigation items', (
    tester,
  ) async {
    await tester.pumpWidget(const PikZenApp());
    appRouter.go('/shop-dashboard');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductsScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(ShopDashboardScreen), findsOneWidget);
    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DashboardBottomNav),
        matching: find.text('Products'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProductsScreen), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(DashboardBottomNav),
        matching: find.text('Orders'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IncomingOrdersScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductsScreen), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(DashboardBottomNav),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    appRouter.pop();
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DashboardBottomNav),
        matching: find.text('Home'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ShopDashboardScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

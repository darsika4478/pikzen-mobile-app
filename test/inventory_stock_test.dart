import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/app.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/shop_management/screens/inventory_stock_screen.dart';
import 'package:pikzen/features/shop_management/screens/add_edit_product_screen.dart';
import 'package:pikzen/features/shop_management/screens/product_management_screen.dart';
import 'package:pikzen/features/shop_management/widgets/inventory_product_card.dart';
import 'package:pikzen/features/shop_management/widgets/dashboard_bottom_nav.dart';

void main() {
  for (final width in [360.0, 375.0, 390.0, 412.0, 430.0]) {
    testWidgets('Inventory fits $width px with fixed update and navigation', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const InventoryStockScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InventoryProductCard), findsNWidgets(4));
      expect(find.text('24'), findsOneWidget);
      expect(find.text('20 units left (Alert < 25)'), findsOneWidget);
      expect(
        tester
            .widget<DashboardBottomNav>(find.byType(DashboardBottomNav))
            .selectedIndex,
        2,
      );
      final update = tester.getRect(find.text('Update Stock'));
      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Update Stock')), update);
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.enterText(find.byType(TextField), 'Milk');
      await tester.pumpAndSettle();
      expect(find.text('Fresh Milk'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Search, filters, dynamic stock, zero floor, batch and update are local',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const InventoryStockScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Low Stock').first);
      await tester.pumpAndSettle();
      expect(find.byType(InventoryProductCard), findsOneWidget);
      expect(find.text('Fresh Milk'), findsOneWidget);
      await tester.tap(find.text('Out of Stock'));
      await tester.pumpAndSettle();
      expect(find.text('No out-of-stock products'), findsOneWidget);
      await tester.tap(find.text('All Items'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Milk');
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byTooltip('Increase Fresh Milk'));
        await tester.pump();
      }
      expect(find.text('25 units left'), findsOneWidget);
      expect(find.text('In Stock'), findsOneWidget);
      await tester.tap(find.text('Low Stock'));
      await tester.pumpAndSettle();
      expect(find.text('No inventory items found'), findsOneWidget);
      await tester.tap(find.text('All Items'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 25; i++) {
        await tester.tap(find.byTooltip('Decrease Fresh Milk'));
        await tester.pump();
      }
      final minus = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == 'Decrease Fresh Milk',
        ),
      );
      expect(minus.onPressed, isNull);
      expect(find.text('0 units left'), findsOneWidget);
      await tester.tap(find.text('Out of Stock').first);
      await tester.pumpAndSettle();
      expect(find.byType(InventoryProductCard), findsOneWidget);
      await tester.tap(find.text('Batch Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      await tester.tap(find.text('Update Stock'));
      await tester.pumpAndSettle();
      expect(find.text('Stock updated successfully'), findsOneWidget);
      expect(find.text('0 units left'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('No inventory items found'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('All Items'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batch Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).at(0)).value,
        isTrue,
      );
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).at(1)).value,
        isTrue,
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Low Stock').first);
      await tester.pumpAndSettle();
      expect(find.text('No inventory items found'), findsOneWidget);
    },
  );
  testWidgets(
    'Products entry, menus, Back and Products tab preserve navigation',
    (tester) async {
      appRouter.goNamed('product-management');
      await tester.pumpWidget(const PikZenApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inventory & Stock'));
      await tester.pumpAndSettle();
      expect(find.byType(InventoryStockScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Red Apple menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Product'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Red Apple menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Product'));
      await tester.pumpAndSettle();
      expect(find.byType(AddEditProductScreen), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Red Apple',
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(InventoryStockScreen), findsOneWidget);
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductsScreen), findsOneWidget);
      await tester.tap(find.text('Inventory & Stock'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductsScreen), findsOneWidget);
      appRouter.goNamed('shop-dashboard');
      await tester.pumpAndSettle();
    },
  );
}

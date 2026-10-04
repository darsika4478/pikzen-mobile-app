import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/app.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/shop_management/models/mock_shop_product.dart';
import 'package:pikzen/features/shop_management/screens/add_edit_product_screen.dart';
import 'package:pikzen/features/shop_management/screens/product_management_screen.dart';
import 'package:pikzen/features/shop_management/widgets/dashboard_bottom_nav.dart';
import 'package:pikzen/features/shop_management/widgets/product_form_controls.dart';
import 'package:pikzen/features/shop_management/widgets/product_image_preview.dart';

void main() {
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  for (final width in [360.0, 375.0, 390.0, 412.0, 430.0]) {
    testWidgets(
      'Add and Edit form fit at $width px and scroll above keyboard',
      (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        for (final product in [null, mockShopProducts.first]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: AddEditProductScreen(
                key: ValueKey(product),
                product: product,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<DashboardBottomNav>(find.byType(DashboardBottomNav))
                .selectedIndex,
            2,
          );
          expect(tester.getRect(find.byType(DashboardBottomNav)).bottom, 700);
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          await tester.pumpAndSettle();
          final description = find.byType(TextFormField).last;
          await reveal(tester, description);
          await tester.enterText(description, 'Updated description');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets(
    'Add validates name, category and price, and quantity stays nonnegative',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AddEditProductScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Delete product'), findsNothing);
      expect(find.text('Delete Product'), findsNothing);
      expect(find.text('Save Changes'), findsNothing);
      expect(find.text('Add Photo'), findsOneWidget);
      expect(find.text('e.g. Fresh Red Apple'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        '0.00',
      );
      final minus = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == 'Decrease stock',
        ),
      );
      expect(minus.onPressed, isNull);
      await tester.tap(find.byType(ProductImagePreview));
      await tester.pumpAndSettle();
      expect(find.text('Add product photo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(ElevatedButton, 'Add Product');
      await reveal(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Enter a product name'), findsOneWidget);
      expect(find.text('Select a category'), findsOneWidget);
      expect(find.text('Enter a price greater than 0'), findsOneWidget);
      final name = find.byType(TextFormField).first;
      await reveal(tester, name);
      await tester.enterText(name, 'New product');
      await reveal(tester, find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Snacks').last);
      await tester.pumpAndSettle();
      final price = find.byType(TextFormField).at(1);
      await reveal(tester, price);
      for (final invalid in ['0', '-1', 'invalid', 'NaN', 'Infinity']) {
        await tester.enterText(price, invalid);
        await reveal(tester, save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text('Enter a price greater than 0'), findsOneWidget);
        expect(find.text('Product added successfully'), findsNothing);
        await reveal(tester, price);
      }
      await tester.enterText(price, '4.50');
      await reveal(tester, find.byType(StockQuantitySelector));
      await tester.tap(find.byTooltip('Increase stock'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StockQuantitySelector>(find.byType(StockQuantitySelector))
            .quantity,
        1,
      );
      await tester.tap(find.byTooltip('Decrease stock'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StockQuantitySelector>(find.byType(StockQuantitySelector))
            .quantity,
        0,
      );
      await reveal(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Product added successfully'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Edit uses supplied fields, saves locally, and both delete controls share a dialog',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AddEditProductScreen(product: mockShopProducts.first),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Red Apple',
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        '5.90',
      );
      expect(
        tester
            .widget<StockQuantitySelector>(find.byType(StockQuantitySelector))
            .quantity,
        50,
      );
      await tester.tap(find.byTooltip('Change product image'));
      await tester.pumpAndSettle();
      expect(find.text('Change product image'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      final save = find.text('Save Changes');
      await reveal(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Product changes saved'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      for (final top in [true, false]) {
        final delete = top
            ? find.byTooltip('Delete product')
            : find.text('Delete Product');
        await reveal(tester, delete);
        await tester.tap(delete);
        await tester.pumpAndSettle();
        expect(
          find.text('Are you sure you want to delete Red Apple?'),
          findsOneWidget,
        );
        await tester.tap(find.text(top ? 'Cancel' : 'Delete'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Product deleted'), findsOneWidget);
      expect(mockShopProducts.first.name, 'Red Apple');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Products opens all edit modes and Add; Back keeps list unchanged',
    (tester) async {
      await tester.pumpWidget(const PikZenApp());
      appRouter.go('/product-management');
      await tester.pumpAndSettle();
      for (final product in mockShopProducts) {
        await reveal(tester, find.text(product.name));
        await tester.tap(find.text(product.name));
        await tester.pumpAndSettle();
        expect(find.text('Edit Product'), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          product.name,
        );
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductsScreen), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Add Product'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        isEmpty,
      );
      expect(find.text('Delete Product'), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductsScreen), findsOneWidget);
      appRouter.go('/shop-dashboard');
      await tester.pumpAndSettle();
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/app.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/profile/screens/profile_screen.dart';
import 'package:pikzen/features/profile/widgets/merchant_profile_view.dart';
import 'package:pikzen/features/profile/widgets/logout_confirmation_dialog.dart';
import 'package:pikzen/features/shop_management/screens/shop_dashboard_screen.dart';
import 'package:pikzen/features/shop_management/screens/incoming_orders_screen.dart';
import 'package:pikzen/features/shop_management/screens/product_management_screen.dart';
import 'package:pikzen/features/shop_management/widgets/dashboard_bottom_nav.dart';

void main() {
  for (final width in [360.0, 375.0, 390.0, 412.0, 430.0]) {
    testWidgets('Merchant profile fits $width px without account providers', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProfileScreen.shopPartner(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('GreenMart'), findsOneWidget);
      expect(find.text('Verified Merchant • ID: #GM8821'), findsOneWidget);
      expect(find.text('12 New'), findsOneWidget);
      expect(find.text('28 Items'), findsOneWidget);
      expect(find.byType(MerchantProfileMenuRow), findsNWidgets(5));
      expect(
        tester
            .widget<DashboardBottomNav>(find.byType(DashboardBottomNav))
            .selectedIndex,
        3,
      );
      expect(tester.getRect(find.byType(DashboardBottomNav)).bottom, 740);
      final title = find.text('Profile').first;
      expect(tester.getCenter(title).dx, closeTo(width / 2, 1));
      await tester.ensureVisible(find.text('Logout'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Preview actions and logout confirmation never require authentication',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProfileScreen.shopPartner(),
        ),
      );
      await tester.pumpAndSettle();
      for (final (finder, message) in [
        (find.byTooltip('Profile settings'), 'Settings'),
        (find.text('Change Password'), 'Change Password'),
        (find.text('Notifications'), 'Notifications'),
        (find.text('Settings'), 'Settings'),
      ]) {
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(message),
          ),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Logout'));
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      expect(find.byType(LogoutConfirmationDialog), findsOneWidget);
      expect(find.text('Are you sure you want to logout?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(LogoutConfirmationDialog), findsNothing);
      expect(find.text('Logout selected'), findsNothing);
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(LogoutConfirmationDialog),
          matching: find.text('Logout'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Logout selected'), findsOneWidget);
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Shop Profile entries, menu destinations, Back and bottom navigation',
    (tester) async {
      await tester.pumpWidget(const PikZenApp());
      appRouter.goNamed('shop-dashboard');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ProfileScreen>(find.byType(ProfileScreen)).isShopPartner,
        isTrue,
      );
      expect(find.byType(MerchantProfileView), findsOneWidget);
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      for (final (label, type) in [
        ('My Orders', IncomingOrdersScreen),
        ('My Products', ProductsScreen),
      ]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.byType(type), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.byType(MerchantProfileView), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(ShopDashboardScreen), findsOneWidget);
      for (final route in [
        'product-management',
        'inventory-stock',
        'add-edit-product',
      ]) {
        appRouter.goNamed(route);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        expect(find.byType(MerchantProfileView), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(
          appRouter.routerDelegate.currentConfiguration.uri.path,
          '/$route',
        );
      }
      appRouter.goNamed('shop-profile');
      await tester.pumpAndSettle();
      for (final (label, type) in [
        ('Orders', IncomingOrdersScreen),
        ('Products', ProductsScreen),
      ]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.byType(type), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.byType(ShopDashboardScreen), findsOneWidget);
      appRouter.goNamed('shop-profile');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(ShopDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/auth/providers/auth_provider.dart';
import 'package:pikzen/features/auth/screens/login_screen.dart';
import 'package:pikzen/features/cart_checkout/providers/cart_provider.dart';
import 'package:pikzen/features/cart_checkout/providers/checkout_provider.dart';
import 'package:pikzen/features/cart_checkout/screens/cart_screen.dart';
import 'package:pikzen/features/product_discovery/providers/product_provider.dart';
import 'package:pikzen/features/product_discovery/screens/customer_home_screen.dart';
import 'package:pikzen/features/product_discovery/screens/categories_screen.dart';
import 'package:pikzen/features/product_discovery/screens/favourites_screen.dart';
import 'package:pikzen/features/profile/screens/profile_screen.dart';
import 'package:pikzen/shared/screens/splash_screen.dart';

import 'auth_test_support.dart';

void main() {
  testWidgets('Startup, common login, five tabs, and shared cart/favourites', (
    tester,
  ) async {
    final auth = AuthProvider(service: FakeAuthService(), restore: false);
    final cart = CartProvider();
    final checkout = CheckoutProvider();
    final products = ProductProvider();
    addTearDown(auth.dispose);
    addTearDown(cart.dispose);
    addTearDown(checkout.dispose);
    addTearDown(products.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: cart),
          ChangeNotifierProvider.value(value: checkout),
          ChangeNotifierProvider.value(value: products),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: appRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'darsika@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerHomeScreen), findsOneWidget);
    expect(find.textContaining('Darsika'), findsOneWidget);
    const labels = ['Home', 'Categories', 'Cart', 'Favourites', 'Profile'];
    const screens = [
      CustomerHomeScreen,
      CategoriesScreen,
      CartScreen,
      FavouritesScreen,
      ProfileScreen,
    ];
    for (var i = 0; i < labels.length; i++) {
      await tester.tap(find.widgetWithText(NavigationDestination, labels[i]));
      await tester.pumpAndSettle();
      expect(find.byType(screens[i]), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        i,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
    await tester.pumpAndSettle();
    final add = find.text('+ Add').first;
    await tester.scrollUntilVisible(
      add,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(cart.quantity('red-apples'), 1);
    await tester.ensureVisible(find.byTooltip('Favourite Red Apples'));
    await tester.tap(find.byTooltip('Favourite Red Apples'));
    await tester.pumpAndSettle();
    expect(products.isFavourite('red-apples'), isTrue);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Red Apples'), findsOneWidget);
    await tester.tap(find.byTooltip('Increase Red Apples'));
    await tester.pumpAndSettle();
    expect(cart.count, 2);
    await tester.tap(find.byTooltip('Decrease Red Apples'));
    await tester.pumpAndSettle();
    expect(cart.count, 1);
    await tester.tap(find.byTooltip('Remove Red Apples'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Item?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(cart.count, 0);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Favourites'));
    await tester.pumpAndSettle();
    expect(find.text('Red Apples'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove Red Apples from favourites'));
    await tester.pumpAndSettle();
    expect(products.favourites, isEmpty);
    appRouter.goNamed('search', queryParameters: {'q': 'eggs'});
    await tester.pumpAndSettle();
    expect(find.text('Farm Fresh Eggs'), findsOneWidget);
    expect(find.text('Red Apples'), findsNothing);
    appRouter.goNamed('categories', queryParameters: {'category': 'Dairy'});
    await tester.pumpAndSettle();
    expect(find.text('Farm Fresh Eggs'), findsOneWidget);
    expect(find.text('Red Apples'), findsNothing);
    appRouter.goNamed('product-details', queryParameters: {'id': 'whole-milk'});
    await tester.pumpAndSettle();
    expect(find.text('Fresh Whole Milk'), findsWidgets);
    expect(find.text('Red Apples'), findsNothing);
    await tester.tap(find.textContaining('Add to Cart').last);
    await tester.pumpAndSettle();
    expect(find.byType(CartScreen), findsOneWidget);
    expect(find.text('Fresh Whole Milk'), findsOneWidget);
    expect(cart.quantity('whole-milk'), 1);
    await tester.scrollUntilVisible(
      find.text('Proceed to Checkout'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final proceed = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Proceed to Checkout'),
    );
    expect(proceed.onPressed, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

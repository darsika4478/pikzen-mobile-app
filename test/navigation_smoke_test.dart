import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/app.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/shared/screens/splash_screen.dart';
import 'package:pikzen/shared/screens/onboarding_screen.dart';
import 'package:pikzen/features/product_discovery/screens/categories_screen.dart';
import 'package:pikzen/features/product_discovery/screens/search_screen.dart';
import 'package:pikzen/features/product_discovery/screens/favourites_screen.dart';
import 'package:pikzen/features/profile/screens/profile_screen.dart';
import 'package:pikzen/features/auth/screens/login_screen.dart';
import 'package:pikzen/features/product_discovery/screens/customer_home_screen.dart';

void main() {
  testWidgets('Startup flow, customer tabs, and temporary menu navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const PikZenApp());
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerHomeScreen), findsOneWidget);

    const screens = [
      CustomerHomeScreen,
      CategoriesScreen,
      SearchScreen,
      FavouritesScreen,
      ProfileScreen,
    ];
    const labels = ['Home', 'Categories', 'Search', 'Favourites', 'Profile'];
    for (var index = 0; index < labels.length; index++) {
      await tester.tap(
        find.widgetWithText(NavigationDestination, labels[index]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(screens[index]), findsOneWidget);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations, hasLength(5));
      expect(bar.selectedIndex, index);
      expect(appRouter.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
    await tester.pumpAndSettle();
    final list = tester.widget<ListView>(find.byType(ListView));
    final children =
        (list.childrenDelegate as SliverChildListDelegate).children;
    final titles = children
        .whereType<ListTile>()
        .map((tile) => (tile.title! as Text).data!)
        .toList();
    expect(titles, hasLength(24));

    for (final title in titles) {
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      final tile = find.widgetWithText(ListTile, title);
      await tester.scrollUntilVisible(tile, 250);
      await tester.pumpAndSettle();
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: title);
      expect(appRouter.canPop(), isTrue, reason: title);
      expect(find.byType(BackButton), findsOneWidget, reason: title);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerHomeScreen), findsOneWidget, reason: title);
      expect(tester.takeException(), isNull, reason: title);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

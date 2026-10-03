import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/auth/providers/auth_provider.dart';
import 'package:pikzen/features/cart_checkout/providers/cart_provider.dart';
import 'package:pikzen/features/product_discovery/providers/product_provider.dart';
import 'package:pikzen/features/profile/screens/profile_screen.dart';
import 'package:pikzen/models/order_model.dart';

import 'auth_test_support.dart';

class _CountingAuthService extends FakeAuthService {
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

OrderModel _order(
  String id,
  String status,
  DateTime createdAt, {
  String? hub,
}) => OrderModel(
  id: id,
  userId: 'test-user',
  items: const [],
  createdAt: createdAt,
  status: status,
  shopName: hub,
);

GoRouter _router(ProfileScreen profile) => GoRouter(
  initialLocation: '/profile',
  routes: [
    GoRoute(path: '/profile', name: 'profile', builder: (_, _) => profile),
    for (final name in [
      'edit-profile',
      'my-orders',
      'favourites',
      'settings',
      'notifications',
      'login',
    ])
      GoRoute(
        path: '/$name',
        name: name,
        builder: (_, _) => Scaffold(body: Text('$name destination')),
      ),
    GoRoute(
      path: '/order-details',
      name: 'order-details',
      builder: (_, state) => Scaffold(
        body: Text('Order details ${(state.extra as OrderModel).id}'),
      ),
    ),
  ],
);

Future<AuthProvider> _signedIn(_CountingAuthService service) async {
  final auth = AuthProvider(service: service, restore: false);
  expect(await auth.signIn('test@example.com', 'password'), isTrue);
  return auth;
}

Widget _app(GoRouter router, AuthProvider auth, ProductProvider products,
        {double textScale = 1}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<ProductProvider>.value(value: products),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
      ),
    );

void main() {
  testWidgets(
    'loads account and orders for the signed-in UID, with live favourites',
    (tester) async {
      final service = _CountingAuthService();
      final auth = await _signedIn(service);
      final products = ProductProvider();
      final profiles = StreamController<Map<String, dynamic>?>.broadcast();
      final orders = StreamController<List<OrderModel>>.broadcast();
      addTearDown(() async {
        await profiles.close();
        await orders.close();
        auth.dispose();
        products.dispose();
      });
      String? requestedProfileUid;
      String? requestedOrdersUid;
      final router = _router(
        ProfileScreen(
          profileDocuments: (uid) {
            requestedProfileUid = uid;
            return profiles.stream;
          },
          ordersForCustomer: (uid) {
            requestedOrdersUid = uid;
            return orders.stream;
          },
        ),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router, auth, products));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(requestedProfileUid, 'test-user');
      expect(requestedOrdersUid, 'test-user');

      profiles.add({
        'fullName': 'Alex Perera',
        'email': 'alex@example.com',
        'phone': '+94770001111',
        'role': 'customer',
      });
      orders.add([
        _order(
          'PZ-8842',
          'ready',
          DateTime.utc(2026, 10, 2),
          hub: 'Colombo 03 Hub',
        ),
        _order('PZ-7000', 'collected', DateTime.utc(2026, 9, 1)),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Alex Perera'), findsOneWidget);
      expect(find.text('alex@example.com'), findsOneWidget);
      expect(find.text('+94770001111'), findsOneWidget);
      expect(find.text('READY FOR PICKUP'), findsOneWidget);
      expect(find.text('Order #PZ-8842'), findsOneWidget);
      expect(find.text('Colombo 03 Hub'), findsWidgets);
      expect(find.text('1'), findsOneWidget); // Completed orders.
      expect(find.text('0 saved local groceries'), findsOneWidget);
      products.toggleFavourite('red-apples');
      await tester.pump();
      expect(find.text('1 saved local groceries'), findsOneWidget);
      await tester.tap(find.text('View Pass'));
      await tester.pumpAndSettle();
      expect(find.text('Order details PZ-8842'), findsOneWidget);
    },
  );

  testWidgets(
    'missing optional data stays readable without an invented order',
    (tester) async {
      final service = _CountingAuthService();
      final auth = await _signedIn(service);
      final products = ProductProvider();
      final router = _router(
        ProfileScreen(
          profileDocuments: (_) => Stream.value(null),
          ordersForCustomer: (_) => Stream.value(const []),
        ),
      );
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      addTearDown(products.dispose);
      await tester.pumpWidget(_app(router, auth, products));
      await tester.pumpAndSettle();
      expect(find.text('Darsika N'), findsOneWidget);
      expect(find.text('darsika@example.com'), findsOneWidget);
      expect(find.text('Phone not added'), findsOneWidget);
      expect(find.text('No pickup location selected'), findsOneWidget);
      expect(find.text('READY FOR PICKUP'), findsNothing);
      expect(find.text('View Pass'), findsNothing);
      expect(find.text('Orders Done'), findsOneWidget);
      expect(find.text('Deals Saved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('uses existing account, order, favourite and settings routes', (
    tester,
  ) async {
    final service = _CountingAuthService();
    final auth = await _signedIn(service);
    final products = ProductProvider();
    final router = _router(
      ProfileScreen(
        profileDocuments: (_) => Stream.value(null),
        ordersForCustomer: (_) => Stream.value(const []),
      ),
    );
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    addTearDown(products.dispose);
    await tester.pumpWidget(_app(router, auth, products));
    await tester.pumpAndSettle();
    for (final (label, route) in [
      ('Edit Profile', 'edit-profile'),
      ('My Orders', 'my-orders'),
      ('Settings', 'settings'),
      ('Favourites', 'favourites'),
    ]) {
      final tile = find.widgetWithText(ListTile, label);
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text('$route destination'), findsOneWidget);
      router.goNamed('profile');
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('notifications destination'), findsOneWidget);
  });

  testWidgets(
    'logout cancel keeps the session; confirm signs out and opens login',
    (tester) async {
      final service = _CountingAuthService();
      final auth = await _signedIn(service);
      final products = ProductProvider();
      final router = _router(
        ProfileScreen(
          profileDocuments: (_) => Stream.value(null),
          ordersForCustomer: (_) => Stream.value(const []),
        ),
      );
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      addTearDown(products.dispose);
      await tester.pumpWidget(_app(router, auth, products));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Logout'));
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.signOutCalls, 0);
      expect(auth.user, isNotNull);
      expect(find.byType(ProfileScreen), findsOneWidget);

      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Logout'));
      await tester.pumpAndSettle();
      expect(service.signOutCalls, 1);
      expect(auth.user, isNull);
      expect(find.text('login destination'), findsOneWidget);
    },
  );

  testWidgets('existing customer navigation selects Profile and reaches Home', (
    tester,
  ) async {
    final service = _CountingAuthService();
    final auth = await _signedIn(service);
    final products = ProductProvider();
    final cart = CartProvider();
    addTearDown(auth.dispose);
    addTearDown(products.dispose);
    addTearDown(cart.dispose);
    appRouter.goNamed('profile');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ProductProvider>.value(value: products),
          ChangeNotifierProvider<CartProvider>.value(value: cart),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: appRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 4);
    expect(bar.destinations.cast<NavigationDestination>().map((destination) => destination.label), [
      'Home',
      'Categories',
      'Cart',
      'Favourites',
      'Profile',
    ]);
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets('profile scrolls at 320 pixels with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _CountingAuthService();
    final auth = await _signedIn(service);
    final products = ProductProvider();
    final router = _router(
      ProfileScreen(
        profileDocuments: (_) => Stream.value({
          'fullName': 'A Customer With A Long Name',
          'email': 'long-email-address@example.com',
          'role': 'customer',
          'photoUrl': 17,
        }),
        ordersForCustomer: (_) => Stream.value([
          _order(
            'PZ-8842',
            'ready',
            DateTime.utc(2026, 10, 2),
            hub: 'Colombo 03 Hub',
          ),
        ]),
      ),
    );
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    addTearDown(products.dispose);
    await tester.pumpWidget(_app(router, auth, products, textScale: 1.6));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

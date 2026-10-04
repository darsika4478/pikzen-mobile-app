import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/services/firestore_service.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/admin/providers/admin_users_provider.dart';
import 'package:pikzen/features/admin/screens/admin_users_screen.dart';
import 'package:pikzen/features/auth/providers/auth_provider.dart';
import 'package:pikzen/features/cart_checkout/providers/cart_provider.dart';
import 'package:pikzen/features/product_discovery/providers/product_provider.dart';
import 'package:pikzen/features/product_discovery/screens/categories_screen.dart';
import 'package:pikzen/features/product_discovery/screens/search_screen.dart';
import 'package:pikzen/features/product_discovery/screens/product_details_screen.dart';
import 'package:pikzen/features/product_discovery/screens/favourites_screen.dart';
import 'package:pikzen/models/product_model.dart';
import 'package:pikzen/models/user_model.dart';

import 'auth_test_support.dart';

const pending = UserModel(
  id: 'shop',
  name: 'Pending Shop',
  email: 'shop@example.com',
  role: 'shop',
  approvalStatus: 'pending',
);
const customer = UserModel(
  id: 'customer',
  name: 'Customer Person',
  email: 'customer@example.com',
);
const admin = UserModel(
  id: 'admin',
  name: 'Admin Person',
  email: 'admin@example.com',
  role: 'admin',
);

class FakeDirectory extends FirestoreService {
  final controller = StreamController<List<UserModel>>.broadcast();
  List<UserModel> data = [pending, customer, admin];
  final List<Map<String, String>> writes = [];
  @override
  Stream<List<UserModel>> users() async* {
    yield data;
    yield* controller.stream;
  }

  @override
  Future<void> reviewShop(
    String shopUid, {
    required String approvalStatus,
  }) async {
    writes.add({'id': shopUid, 'approvalStatus': approvalStatus});
    data = data
        .map(
          (u) => u.id == shopUid
              ? UserModel(
                  id: u.id,
                  name: u.name,
                  email: u.email,
                  role: u.role,
                  approvalStatus: approvalStatus,
                )
              : u,
        )
        .toList();
    controller.add(data);
  }
}

void main() {
  test('Safe Firestore parsing and quantity-derived stock', () {
    for (final amount in [0, 5, 40]) {
      final p = ProductModel.fromMap('p', {
        'stockQuantity': amount,
        'price': 990,
      });
      expect(p.priceMinor, 99000);
      expect(
        p.stock,
        amount == 0
            ? StockStatus.outOfStock
            : amount == 5
            ? StockStatus.lowStock
            : StockStatus.inStock,
      );
    }
    final p = ProductModel.fromMap('bad', {
      'name': 3,
      'priceMinor': double.nan,
      'stockQuantity': -1,
      'imageUrl': [],
    });
    expect(p.stockQuantity, 0);
    expect(p.priceMinor, 0);
    expect(p.name, 'Unnamed product');
    expect(
      ProductModel.fromMap('p', {'category': 'Dairy'}).category,
      'Dairy & Eggs',
    );
  });
  test('Live catalog refreshes favourite prices and cart limits; stale adds denied', () async {
    final source = StreamController<List<ProductModel>>();
    final products = ProductProvider(source: source.stream);
    final cart = CartProvider();
    void sync() => cart.syncProducts(products.products);
    products.addListener(sync);
    final first = ProductModel.fromMap('p', {
      'name': 'Apple',
      'priceMinor': 95000,
      'stockQuantity': 25,
    });
    source.add([first]);
    await Future<void>.delayed(Duration.zero);
    expect(products.isDemo, isFalse);
    products.toggleFavourite('p');
    for (var i = 0; i < 10; i++) {
      cart.add(first);
    }
    source.add([
      ProductModel.fromMap('p', {'priceMinor': 99000, 'stockQuantity': 5}),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(products.favourites.single.priceMinor, 99000);
    expect(products.byId('p')!.stock, StockStatus.lowStock);
    expect(cart.quantity('p'), 5);
    expect(cart.totalMinor, 495000);
    expect(cart.add(first), isFalse);
    source.add([
      ProductModel.fromMap('p', {'priceMinor': 99000, 'stockQuantity': 0}),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(cart.count, 0);
    expect(cart.add(first), isFalse);
    source.add([]);
    await Future<void>.delayed(Duration.zero);
    expect(products.products, isEmpty);
    expect(products.isDemo, isFalse);
    products.removeListener(sync);
    products.dispose();
    cart.dispose();
    await source.close();
  });
  test('Empty initial source retains demo fallback', () async {
    final p = ProductProvider(source: Stream.value([]));
    await Future<void>.delayed(Duration.zero);
    expect(p.isDemo, isTrue);
    expect(p.products, ProductProvider.catalog);
    p.dispose();
  });
  test('Admin filters and status-only approval', () async {
    final service = FakeDirectory();
    final users = AdminUsersProvider(service: service);
    await Future<void>.delayed(Duration.zero);
    expect(users.matching('All', '').length, 3);
    expect(users.matching('Customers', '').single.id, 'customer');
    expect(users.matching('Shop Owners', 'shop').single.id, 'shop');
    expect(users.matching('Pending Shops', '').single.id, 'shop');
    expect(users.matching('All', 'ADMIN@').single.id, 'admin');
    expect(await users.review(pending, 'approved'), isTrue);
    expect(service.writes.single, {'id': 'shop', 'approvalStatus': 'approved'});
    expect(users.matching('Pending Shops', ''), isEmpty);
    users.dispose();
    await service.controller.close();
  });
  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) =>
                AuthProvider(service: FakeAuthService(), restore: false),
          ),
          ChangeNotifierProvider(
            create: (_) => ProductProvider()..toggleFavourite('red-apples'),
          ),
          ChangeNotifierProvider(create: (_) => CartProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 640),
              textScaler: TextScaler.linear(scale),
            ),
            child: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Discovery and admin fit small screens and large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final scale in [1.0, 2.0]) {
      for (final screen in [
        const CategoriesScreen(),
        const SearchScreen(query: 'apple'),
        const ProductDetailsScreen(productId: 'red-apples'),
        const FavouritesScreen(),
        const AdminUsersScreen(),
      ]) {
        await mount(tester, screen, scale: scale);
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.runtimeType} scale $scale',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
  testWidgets(
    'All categories route to filtered search; selected details use shared cart',
    (tester) async {
      final auth = AuthProvider(service: FakeAuthService(), restore: false);
      final products = ProductProvider();
      final cart = CartProvider();
      addTearDown(auth.dispose);
      addTearDown(products.dispose);
      addTearDown(cart.dispose);
      appRouter.go('/categories');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: products),
            ChangeNotifierProvider.value(value: cart),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: appRouter,
          ),
        ),
      );
      for (final name in ProductProvider.categoryImages.keys) {
        appRouter.go('/categories');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(name));
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
        expect(find.byType(SearchScreen), findsOneWidget);
        expect(
          tester.widget<SearchScreen>(find.byType(SearchScreen)).category,
          name,
        );
        expect(find.byType(ProductDetailsScreen), findsNothing);
        expect(find.byType(NavigationBar), findsOneWidget);
      }
      appRouter.go('/categories');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'milk');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Fresh Whole Milk'), findsOneWidget);
      await tester.tap(find.byTooltip('Favourite Fresh Whole Milk'));
      await tester.pumpAndSettle();
      expect(products.favourites.single.id, 'whole-milk');
      await tester.tap(find.text('Fresh Whole Milk'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ProductDetailsScreen>(find.byType(ProductDetailsScreen))
            .productId,
        'whole-milk',
      );
      await tester.tap(
        find.byTooltip('Remove Fresh Whole Milk from favourites'),
      );
      await tester.pumpAndSettle();
      expect(products.favourites, isEmpty);
      await tester.tap(find.textContaining('Add to Cart •'));
      await tester.pumpAndSettle();
      expect(cart.quantity('whole-milk'), 1);
      expect(appRouter.routeInformationProvider.value.uri.path, '/cart');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Admin route blocks customer/shop, permits admin and logout', (
    tester,
  ) async {
    final auth = AuthProvider(
      service: FakeAuthService(role: 'admin'),
      restore: false,
    );
    final products = ProductProvider();
    final cart = CartProvider();
    addTearDown(auth.dispose);
    addTearDown(products.dispose);
    addTearDown(cart.dispose);
    appRouter.go('/login');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: products),
          ChangeNotifierProvider.value(value: cart),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: appRouter,
        ),
      ),
    );
    for (final user in [customer, pending]) {
      auth.user = user;
      appRouter.go('/admin/users');
      await tester.pumpAndSettle();
      expect(appRouter.routeInformationProvider.value.uri.path, '/login');
    }
    expect(await auth.signIn('admin@example.com', 'Password123'), isTrue);
    expect(auth.destination, 'admin-users');
    appRouter.goNamed(auth.destination!);
    await tester.pumpAndSettle();
    expect(find.byType(AdminUsersScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Logout'));
    await tester.pumpAndSettle();
    expect(auth.user, isNull);
    expect(appRouter.routeInformationProvider.value.uri.path, '/login');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final decision in ['Approve', 'Reject']) {
    testWidgets('Admin $decision confirms and removes pending shop', (
      tester,
    ) async {
      final service = FakeDirectory();
      addTearDown(service.controller.close);
      await mount(tester, AdminUsersScreen(service: service));
      await tester.ensureVisible(
        find.widgetWithText(ChoiceChip, 'Pending Shops'),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Pending Shops'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(decision));
      await tester.tap(find.text(decision));
      await tester.pumpAndSettle();
      expect(find.text('$decision Shop Owner?'), findsOneWidget);
      expect(service.writes, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, decision).last);
      await tester.pumpAndSettle();
      expect(
        service.writes.single['approvalStatus'],
        decision == 'Approve' ? 'approved' : 'rejected',
      );
      expect(find.text('No matching users.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

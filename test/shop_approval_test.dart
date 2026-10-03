import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/services/auth_service.dart';
import 'package:pikzen/core/services/firestore_service.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/auth/providers/auth_provider.dart';
import 'package:pikzen/features/auth/screens/shop_approval_status_screen.dart';
import 'package:pikzen/features/auth/widgets/auth_ui.dart';
import 'package:pikzen/features/cart_checkout/providers/cart_provider.dart';
import 'package:pikzen/features/product_discovery/providers/product_provider.dart';
import 'package:pikzen/features/shop_management/screens/shop_dashboard_screen.dart';
import 'package:pikzen/models/user_model.dart';

import 'auth_test_support.dart';

class RecordingProfiles extends FirestoreService {
  String? recordedRole;
  @override
  Future<void> createPublicUser({
    required String uid,
    required String name,
    required String email,
    String? phone,
    String role = 'customer',
  }) async {
    recordedRole = role;
  }
}

void main() {
  test('Public profile data uses customer or pending shop, never admin', () {
    for (final role in ['customer', 'shop']) {
      final data = FirestoreService.registrationData(
        uid: 'u',
        name: 'Name',
        email: 'name@example.com',
        role: role,
      );
      expect(data['role'], role);
      expect(data.containsKey('approvalStatus'), role == 'shop');
      if (role == 'shop') expect(data['approvalStatus'], 'pending');
      expect(data['createdAt'], isA<FieldValue>());
      expect(data.containsKey('password'), isFalse);
    }
    expect(
      () => FirestoreService.registrationData(
        uid: 'u',
        name: 'Name',
        email: 'name@example.com',
        role: 'admin',
      ),
      throwsArgumentError,
    );
  });
  test('Auth service rejects public admin before calling Firebase', () async {
    await expectLater(
      AuthService().register(
        name: 'Name',
        email: 'name@example.com',
        phone: '+94771234567',
        password: 'Password123',
        role: 'admin',
      ),
      throwsA(isA<AuthFailure>()),
    );
  });
  test('Google profile creation defaults to customer', () async {
    final profiles = RecordingProfiles();
    await profiles.createCustomer(
      uid: 'google',
      name: 'Google User',
      email: 'google@example.com',
    );
    expect(profiles.recordedRole, 'customer');
  });
  test('Legacy customers and shops deserialize safely with timestamp', () {
    final date = DateTime.utc(2026);
    final customer = UserModel.fromMap('customer', {
      'fullName': 'Name',
      'role': 'customer',
      'createdAt': Timestamp.fromDate(date),
    });
    expect(customer.approvalStatus, isNull);
    expect(customer.createdAt?.isAtSameMomentAs(date), isTrue);
    final shop = UserModel.fromMap('shop', {'role': 'shop'});
    expect(shop.isApprovedShop, isFalse);
  });
  for (final status in <String?>[
    null,
    'pending',
    'approved',
    'rejected',
    'invalid',
  ]) {
    test('Shop login and Google respect approval status: $status', () async {
      final auth = AuthProvider(
        service: FakeAuthService(role: 'shop', approvalStatus: status),
        restore: false,
      );
      addTearDown(auth.dispose);
      for (final google in [false, true]) {
        final ok = google
            ? await auth.google()
            : await auth.signIn('shop@example.com', 'Password123');
        expect(ok, status != 'invalid');
        expect(auth.destination, switch (status) {
          null || 'pending' => 'shop-pending',
          'approved' => 'shop-dashboard',
          'rejected' => 'shop-rejected',
          _ => null,
        });
        expect(auth.error, status == 'invalid' ? isNotNull : isNull);
      }
    });
  }
  test('Registration routes pending shop to its status screen', () async {
    final auth = AuthProvider(
      service: FakeAuthService(role: 'shop', approvalStatus: 'pending'),
      restore: false,
    );
    addTearDown(auth.dispose);
    expect(
      await auth.register(
        'Name',
        'shop@example.com',
        '+94771234567',
        'Password123',
        role: 'shop',
      ),
      isTrue,
    );
    expect(auth.user?.approvalStatus, 'pending');
    expect(auth.destination, 'shop-pending');
    expect(
      await auth.register(
        'Name',
        'customer@example.com',
        '+94771234567',
        'Password123',
      ),
      isTrue,
    );
    expect(auth.user?.approvalStatus, isNull);
    expect(auth.destination, 'customer-home');
  });

  Future<AuthProvider> mount(
    WidgetTester tester,
    String path, {
    UserModel? user,
    FakeAuthService? service,
  }) async {
    final auth = AuthProvider(
      service: service ?? FakeAuthService(),
      restore: false,
    )..user = user;
    final cart = CartProvider();
    final products = ProductProvider();
    addTearDown(auth.dispose);
    addTearDown(cart.dispose);
    addTearDown(products.dispose);
    appRouter.go(path);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: cart),
          ChangeNotifierProvider.value(value: products),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: appRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  for (final (role, status, expectedPath) in [
    ('customer', null, '/customer-home'),
    ('shop', null, '/shop-pending'),
    ('shop', 'pending', '/shop-pending'),
    ('shop', 'approved', '/shop-dashboard'),
    ('shop', 'rejected', '/shop-rejected'),
    ('admin', null, '/admin/users'),
  ]) {
    testWidgets('Common Login routes $role/$status to $expectedPath', (
      tester,
    ) async {
      await mount(
        tester,
        '/login',
        service: FakeAuthService(role: role, approvalStatus: status),
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'shop@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Sign In'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.ensureVisible(find.text('Sign In'));
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(appRouter.routeInformationProvider.value.uri.path, expectedPath);
      if (role != 'shop' || status == 'approved') {
        expect(find.byType(ShopApprovalStatusScreen), findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final role in ['customer', 'shop']) {
    testWidgets('Signup selector and completion for $role', (tester) async {
      final auth = await mount(tester, '/signup');
      expect(find.byType(ChoiceChip), findsNWidgets(2));
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Customer'))
            .selected,
        isTrue,
      );
      expect(find.text('Admin'), findsNothing);
      await tester.ensureVisible(find.text('Shop Owner'));
      await tester.tap(find.text('Shop Owner'));
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Shop Owner'))
            .selected,
        isTrue,
      );
      if (role == 'customer') {
        await tester.tap(find.text('Customer'));
        await tester.pump();
      }
      final values = [
        'Test Person',
        'person@example.com',
        '771234567',
        'Password123',
        'Password123',
      ];
      for (var i = 0; i < values.length; i++) {
        await tester.enterText(find.byType(TextFormField).at(i), values[i]);
      }
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.byType(AuthAction));
      await tester.tap(find.text('Create Account').last);
      await tester.pumpAndSettle();
      expect(auth.user?.role, role);
      if (role == 'shop') {
        expect(
          appRouter.routeInformationProvider.value.uri.path,
          '/shop-pending',
        );
        expect(find.text('Registration Submitted'), findsOneWidget);
        expect(
          find.text('Your shop account is awaiting admin approval.'),
          findsOneWidget,
        );
        expect(find.byType(ShopDashboardScreen), findsNothing);
        await tester.tap(find.text('Back to Login'));
        await tester.pumpAndSettle();
        expect(appRouter.routeInformationProvider.value.uri.path, '/login');
        expect(auth.user, isNull);
      } else {
        expect(
          appRouter.routeInformationProvider.value.uri.path,
          '/customer-home',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'Direct shop routes deny unapproved accounts and allow approved shop',
    (tester) async {
      final auth = await mount(tester, '/login');
      for (final status in <String?>[null, 'pending', 'rejected', 'approved']) {
        auth.user = UserModel(
          id: 's',
          name: 'Shop',
          email: 'shop@example.com',
          role: 'shop',
          approvalStatus: status,
        );
        for (final path in ['/shop-dashboard', '/inventory']) {
          appRouter.go(path);
          await tester.pumpAndSettle();
          expect(
            appRouter.routeInformationProvider.value.uri.path,
            switch (status) {
              null || 'pending' => '/shop-pending',
              'rejected' => '/shop-rejected',
              _ => path,
            },
          );
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Rejected shop sees status and Back to Login signs out', (
    tester,
  ) async {
    final auth = await mount(
      tester,
      '/login',
      user: const UserModel(
        id: 'shop',
        name: 'Shop Owner',
        email: 'shop@example.com',
        role: 'shop',
        approvalStatus: 'rejected',
      ),
    );
    appRouter.goNamed('shop-rejected');
    await tester.pumpAndSettle();
    expect(find.text('Shop Account Not Approved'), findsOneWidget);
    expect(find.text('NOT APPROVED'), findsOneWidget);
    await tester.tap(find.text('Back to Login'));
    await tester.pumpAndSettle();
    expect(auth.user, isNull);
    expect(appRouter.routeInformationProvider.value.uri.path, '/login');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final decision in ['approved', 'rejected']) {
    testWidgets(
      'Live pending decision $decision opens the correct destination',
      (tester) async {
        final changes = StreamController<Map<String, dynamic>?>.broadcast();
        addTearDown(changes.close);
        final auth = AuthProvider(
          service: FakeAuthService(role: 'shop', approvalStatus: 'pending'),
          restore: false,
        );
        addTearDown(auth.dispose);
        expect(await auth.signIn('shop@example.com', 'Password123'), isTrue);
        final router = GoRouter(
          initialLocation: '/shop-pending',
          routes: [
            GoRoute(
              path: '/shop-pending',
              name: 'shop-pending',
              builder: (_, _) => ShopApprovalStatusScreen(
                rejected: false,
                profileDocuments: (_) => changes.stream,
              ),
            ),
            GoRoute(
              path: '/shop-dashboard',
              name: 'shop-dashboard',
              builder: (_, _) =>
                  const Scaffold(body: Text('Existing Shop Dashboard')),
            ),
            GoRoute(
              path: '/shop-rejected',
              name: 'shop-rejected',
              builder: (_, _) =>
                  const Scaffold(body: Text('Rejected destination')),
            ),
            GoRoute(
              path: '/login',
              name: 'login',
              builder: (_, _) => const Scaffold(body: Text('Common Login')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pump();
        changes.add({'role': 'shop', 'approvalStatus': 'pending'});
        await tester.pumpAndSettle();
        expect(find.text('Registration Submitted'), findsOneWidget);
        changes.add({'role': 'shop', 'approvalStatus': decision});
        await tester.pumpAndSettle();
        expect(
          auth.destination,
          decision == 'approved' ? 'shop-dashboard' : 'shop-rejected',
        );
        expect(
          router.routeInformationProvider.value.uri.path,
          decision == 'approved' ? '/shop-dashboard' : '/shop-rejected',
        );
        expect(
          find.text(
            decision == 'approved'
                ? 'Existing Shop Dashboard'
                : 'Rejected destination',
          ),
          findsOneWidget,
        );
      },
    );
  }
}

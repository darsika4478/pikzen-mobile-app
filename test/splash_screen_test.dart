import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pikzen/core/constants/app_assets.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/auth/providers/auth_provider.dart';
import 'package:pikzen/models/user_model.dart';
import 'package:pikzen/shared/screens/splash_screen.dart';

import 'auth_test_support.dart';

void main() {
  testWidgets('Splash waits eight seconds and replaces its route', (
    tester,
  ) async {
    final auth = AuthProvider(service: FakeAuthService(), restore: false);
    addTearDown(auth.dispose);
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (_, _) =>
              const Scaffold(body: Text('Onboarding destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 7999));
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Onboarding destination'), findsOneWidget);
    expect(router.canPop(), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (role, approval, destination) in [
    ('customer', null, 'customer-home'),
    ('shop', 'approved', 'shop-dashboard'),
    ('shop', 'pending', 'shop-pending'),
    ('shop', 'rejected', 'shop-rejected'),
    ('admin', null, 'admin-users'),
  ]) {
    testWidgets('Restored $role/$approval skips onboarding', (tester) async {
      final auth = AuthProvider(service: FakeAuthService(), restore: false)
        ..user = UserModel(
          id: 'signed-in',
          name: 'Signed In',
          email: 'user@example.com',
          role: role,
          approvalStatus: approval,
        );
      addTearDown(auth.dispose);
      final router = GoRouter(
        initialLocation: '/splash',
        routes: [
          GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
          GoRoute(
            path: '/$destination',
            name: destination,
            builder: (_, _) =>
                const Scaffold(body: Text('Signed-in destination')),
          ),
          GoRoute(
            path: '/onboarding',
            name: 'onboarding',
            builder: (_, _) =>
                const Scaffold(body: Text('Onboarding destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/$destination');
      expect(find.text('Onboarding destination'), findsNothing);
    });
  }

  testWidgets('Splash fits mobile sizes and cancels its timer when removed', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(568, 320),
    ]) {
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: const SplashScreen(),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '$size, text scale $scale',
        );
        expect(find.text('Local Groceries, Easy Pickup'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 8));
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('Existing bundled logo decodes successfully', (tester) async {
    await tester.runAsync(() async {
      final data = await rootBundle.load(AppAssets.logo);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      expect(frame.image.width, greaterThan(0));
      expect(frame.image.height, greaterThan(0));
      frame.image.dispose();
      codec.dispose();
    });
  });
}

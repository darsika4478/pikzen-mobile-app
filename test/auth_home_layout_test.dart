import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/auth/providers/auth_provider.dart';
import 'package:pikzen/features/auth/screens/login_screen.dart';
import 'package:pikzen/features/auth/screens/signup_screen.dart';
import 'package:pikzen/features/auth/screens/forgot_password_screen.dart';
import 'package:pikzen/features/product_discovery/providers/product_provider.dart';
import 'package:pikzen/features/product_discovery/screens/customer_home_screen.dart';
import 'package:pikzen/features/cart_checkout/providers/cart_provider.dart';

import 'auth_test_support.dart';

void main() {
  testWidgets('Auth and home fit small screens and enlarged text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final auth = AuthProvider(service: FakeAuthService(), restore: false);
    final cart = CartProvider();
    final products = ProductProvider();
    addTearDown(auth.dispose);
    addTearDown(cart.dispose);
    addTearDown(products.dispose);
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      for (final scale in [1.0, 2.0]) {
        for (final screen in [
          const LoginScreen(),
          const SignUpScreen(),
          const ForgotPasswordScreen(),
          const CustomerHomeScreen(),
        ]) {
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: auth),
                ChangeNotifierProvider.value(value: cart),
                ChangeNotifierProvider.value(value: products),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: screen,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${screen.runtimeType} $size scale $scale',
          );
          if (screen is CustomerHomeScreen) {
            await tester.drag(
              find.byType(SingleChildScrollView).first,
              const Offset(0, -1600),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    }
  });
  testWidgets('All referenced auth and catalog images decode', (tester) async {
    final assets = [
      ...ProductProvider.catalog.map((p) => p.imageUrl!),
      ...ProductProvider.categoryImages.values,
      'assets/icons/Google icon.png',
      'assets/images/forgot pw.png',
      'assets/images/Hotline.png',
    ];
    await tester.runAsync(() async {
      for (final path in assets) {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
      }
    });
  });
}

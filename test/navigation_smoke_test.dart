import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/auth/providers/auth_provider.dart';
import 'package:pikzen/features/auth/screens/login_screen.dart';
import 'package:pikzen/features/product_discovery/screens/customer_home_screen.dart';
import 'package:pikzen/shared/screens/splash_screen.dart';

import 'auth_test_support.dart';

void main() {
  testWidgets(
    'Splash and onboarding reach common login and the customer destination',
    (tester) async {
      final auth = AuthProvider(service: FakeAuthService(), restore: false);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider.value(value: auth)],
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
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

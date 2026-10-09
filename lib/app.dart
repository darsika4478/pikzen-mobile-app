import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/cart_checkout/providers/cart_provider.dart';
import 'features/cart_checkout/providers/checkout_provider.dart';
import 'features/product_discovery/providers/product_provider.dart';

class PikZenApp extends StatelessWidget {
  const PikZenApp({super.key});
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProxyProvider<AuthProvider, ProductProvider>(
        create: (_) => ProductProvider(),
        update: (_, auth, products) => products!..bindUser(auth.user?.id),
      ),
      ChangeNotifierProxyProvider2<AuthProvider, ProductProvider, CartProvider>(
        create: (_) => CartProvider(),
        update: (_, auth, products, cart) => cart!
          ..bindUser(auth.user?.id)
          ..syncProducts(products.products),
      ),
      ChangeNotifierProxyProvider<AuthProvider, CheckoutProvider>(
        create: (_) => CheckoutProvider(),
        update: (_, auth, checkout) => checkout!..bindUser(auth.user?.id),
      ),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppStrings.appName,
      theme: AppTheme.lightTheme,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: appRouter,
    ),
  );
}

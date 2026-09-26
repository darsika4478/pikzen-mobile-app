import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/providers/auth_provider.dart';

import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class PikZenApp extends StatelessWidget {
  const PikZenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: AppStrings.appName,
        theme: AppTheme.lightTheme,
        routerConfig: appRouter,
      ),
    );
  }
}

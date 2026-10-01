import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Begin once the first frame is displayed, rather than during app setup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timer = Timer(const Duration(seconds: 8), () {
        if (mounted) context.goNamed('onboarding');
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.softGreen,
              AppColors.background,
              Color(0xFFF8F9FF),
            ],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.5, -0.45),
              radius: 1,
              colors: [
                AppColors.primaryLight.withValues(alpha: 0.10),
                Colors.transparent,
              ],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(1, 0.45),
                radius: 0.9,
                colors: [
                  AppColors.accent.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                  final height = math.max(
                    constraints.maxHeight,
                    620.0 * math.max(1.0, scale),
                  );
                  return SingleChildScrollView(
                    child: SizedBox(
                      height: height,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface.withValues(
                                    alpha: 0.95,
                                  ),
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.06,
                                    ),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _StatusDot(
                                      color: AppColors.primary,
                                      size: 6,
                                    ),
                                    SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        'LIVE FRESH HUB',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: height * 0.12),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(26),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.10,
                                        ),
                                        blurRadius: 28,
                                        offset: const Offset(0, 8),
                                      ),
                                      BoxShadow(
                                        color: AppColors.accent.withValues(
                                          alpha: 0.08,
                                        ),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    // Crop the JPEG's empty side margins, keeping the full basket visible.
                                    child: Image.asset(
                                      AppAssets.logo,
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.center,
                                      excludeFromSemantics: true,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -6,
                                  top: -6,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.verified_outlined,
                                      size: 16,
                                      color: AppColors.surface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,

                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      AppStrings.appName,
                                      style: textTheme.headlineLarge?.copyWith(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1.4,
                                        color: AppColors.primaryText,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const _StatusDot(
                                  color: AppColors.primary,
                                  size: 10,
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Local Groceries, Easy Pickup',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.primaryText,
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _StatusDot(color: AppColors.primary),
                                SizedBox(width: 8),
                                _StatusDot(color: AppColors.primaryLight),
                                SizedBox(width: 8),
                                _StatusDot(color: AppColors.accent),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Preparing fresh local stalls...',
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F5FC),
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'Local Fast Collection',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.primaryText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'v2.1.0 \u2022 Sri Lanka',
                              style: textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            SizedBox(height: height * 0.10),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

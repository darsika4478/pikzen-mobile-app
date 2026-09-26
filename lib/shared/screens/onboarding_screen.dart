import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';

/// Three user-controlled introduction pages on the existing onboarding route.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _changingPage = false;

  Future<void> _showPage(int page) async {
    if (_changingPage || page < 0 || page > 2) return;
    setState(() => _changingPage = true);
    await _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
    if (mounted) setState(() => _changingPage = false);
  }

  void _finish() => context.goNamed('login');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _page > 0) _showPage(_page - 1);
      },
      child: Scaffold(
        backgroundColor: _page == 0 ? null : const Color(0xFFF8F9FF),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      _page == 0 ? 24 : 16,
                      12,
                      16,
                      8,
                    ),
                    child: Row(
                      children: [
                        if (_page == 2) ...[
                          IconButton.filledTonal(
                            tooltip: 'Back',
                            onPressed: _changingPage
                                ? null
                                : () => _showPage(1),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF0F5FC),
                              foregroundColor: AppColors.primaryText,
                            ),
                            icon: const Icon(Icons.arrow_back),
                          ),
                        ],
                        Flexible(
                          fit: _page == 2 ? FlexFit.tight : FlexFit.loose,
                          child: Align(
                            widthFactor: 1,
                            alignment: _page == 2
                                ? Alignment.center
                                : Alignment.centerLeft,
                            child: _StepBadge(page: _page),
                          ),
                        ),
                        if (_page != 2) const Spacer(),
                        TextButton(
                          onPressed: _finish,
                          child: const Text('Skip'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (page) => setState(() => _page = page),
                      children: const [
                        _OnboardingPage(index: 0),
                        _OnboardingPage(index: 1),
                        _OnboardingPage(index: 2),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      _page == 0 ? 24 : 16,
                      16,
                      _page == 0 ? 24 : 16,
                      _page == 0
                          ? 20
                          : (MediaQuery.sizeOf(context).height - 700).clamp(
                              20.0,
                              140.0,
                            ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PageIndicator(page: _page),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            if (_page > 0) ...[
                              Expanded(
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFFF0F5FC),
                                    foregroundColor: AppColors.primaryText,
                                    minimumSize: const Size(0, 52),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: _changingPage
                                      ? null
                                      : () => _showPage(_page - 1),
                                  child: const Text('Back'),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              flex:
                                  _page == 0 ||
                                      MediaQuery.textScalerOf(context)
                                              .scale(14) >
                                          20
                                  ? 2
                                  : 3,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 52),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: _changingPage
                                    ? null
                                    : _page == 2
                                    ? _finish
                                    : () => _showPage(_page + 1),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _page == 2 ? 'Get Started' : 'Next',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.index});

  final int index;

  static const _images = [
    AppAssets.onboarding1,
    AppAssets.onboarding2,
    AppAssets.onboarding3,
  ];
  static const _imageDescriptions = [
    'Fresh fruit and vegetable basket. 100% farm-fresh.',
    'PikZen Corner Market, a local grocery shop.',
    'Prepared grocery bag. Express Slot: Ready in 15 mins! Order #8421: Pre-packed & Chilled. Zero supermarket lines.',
  ];
  static const _descriptions = [
    'Browse and pre-order fresh groceries from trusted local shops and neighborhood markets across Colombo and nearby areas.',
    'Shop directly from nearby family-run grocery stores, specialty bakeries, and local markets to support your community while getting the best quality.',
    'Order ahead and collect your groceries at a convenient pickup time without waiting in long supermarket queues.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight = index == 0
            ? (constraints.maxHeight * 0.48).clamp(190.0, 320.0)
            : (constraints.maxWidth - 32) * (index == 1 ? 0.79 : 0.75);
        return SingleChildScrollView(
          key: PageStorageKey('onboarding-page-$index'),
          padding: EdgeInsets.symmetric(
            horizontal: index == 0 ? 24 : 16,
            vertical: 8,
          ),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  // These local exports already include the reference's badges.
                  child: Image.asset(
                    _images[index],
                    width: double.infinity,
                    height: imageHeight,
                    fit: index == 0 ? BoxFit.cover : BoxFit.contain,
                    semanticLabel: _imageDescriptions[index],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (index == 0) ...[
                const _FeatureChip(
                  icon: Icons.storefront_outlined,
                  label: 'Over 140+ neighborhood markets curated',
                ),
                const SizedBox(height: 20),
              ],
              if (index == 1) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    AppAssets.logo,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text.rich(
                TextSpan(
                  children: index == 0
                      ? const [
                          TextSpan(text: 'Fresh Groceries at\n'),
                          TextSpan(
                            text: 'Your Fingertips',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ]
                      : [
                          TextSpan(
                            text: index == 1
                                ? 'Support Local Shops'
                                : 'Save Time, Live Better',
                          ),
                        ],
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: index == 0 ? null : 26,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _descriptions[index],
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: index == 0
                      ? AppColors.secondaryText
                      : AppColors.primaryText.withValues(alpha: 0.8),
                  fontSize: index == 0 ? null : 15,
                  height: 1.55,
                ),
              ),
              if (index == 1) ...[
                const SizedBox(height: 20),
                const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FeatureChip(
                      icon: Icons.eco_outlined,
                      label: 'Zero Warehouses',
                      backgroundColor: Color(0xFFF0F5FC),
                    ),
                    _FeatureChip(
                      icon: Icons.bakery_dining_outlined,
                      label: 'Fresh Morning Bakes',
                      backgroundColor: Color(0xFFF0F5FC),
                      color: AppColors.accent,
                    ),
                  ],
                ),
              ],
              if (index == 2) ...[
                const SizedBox(height: 22),
                const IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _BenefitCard(
                          icon: Icons.calendar_month_outlined,
                          title: 'Book Slot',
                          subtitle: 'To your schedule',
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _BenefitCard(
                          icon: Icons.shopping_bag_outlined,
                          title: 'Carefully Packed',
                          subtitle: 'Peak freshness',
                          color: AppColors.accent,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _BenefitCard(
                          icon: Icons.qr_code,
                          title: 'Drive & Go',
                          subtitle: 'Scan & roll out',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.page});
  final int page;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: page == 0 ? AppColors.softGreen : const Color(0xFFE8EFFF),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Text(
        page == 0
            ? '\u25CF Step 1 of 3'
            : page == 1
            ? 'STEP 2 of 3'
            : '\u25CF STEP 3 OF 3',
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.page});
  final int page;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Page ${page + 1} of 3',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          3,
          (index) => Container(
            width: page == index ? 28 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: page == index ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.icon,
    required this.label,
    this.color = AppColors.primary,
    this.backgroundColor = AppColors.softGreen,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = AppColors.primary,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

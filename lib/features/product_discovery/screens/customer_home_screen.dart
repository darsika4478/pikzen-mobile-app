import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart_checkout/widgets/cart_badge.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/discovery_ui.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthProvider>().firstName;
    final products = context.watch<ProductProvider>().products;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        toolbarHeight:
            56 *
            (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0),
        leading: const Icon(
          Icons.shopping_basket_outlined,
          color: AppColors.primary,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PIKZEN LOCAL',
              style: TextStyle(fontSize: 10, color: AppColors.primary),
            ),
            Text('Home', style: TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.pushNamed('notifications'),
            icon: const Icon(Icons.notifications_none),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              AppAssets.logo,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CatalogNotice(),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name == null
                                  ? 'Hello \u{1F44B}'
                                  : 'Hello, $name \u{1F44B}',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Downtown Colombo Hub \u2022 Curbside Ready',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Open cart',
                        onPressed: () => context.goNamed('cart'),
                        icon: const CartBadge(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    readOnly: true,
                    onTap: () => context.pushNamed('search'),
                    decoration: const InputDecoration(
                      hintText:
                          'Search fresh vegetables, rice, fruits, bakery...',
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: Icon(Icons.tune),
                      hintMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF185B27)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SPECIAL OFFER  \u2022  Today Only',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Fresh Harvest Weekend',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          '20% Off Local Greens & Seasonal Organic Produce',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 20,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'HARVEST20',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            FilledButton(
                              onPressed: () => ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Offer preview. Promotional checkout is not available yet.',
                                      ),
                                    ),
                                  ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Claim Deal →'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Categories',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.goNamed('categories'),
                        child: const Text('See All →'),
                      ),
                    ],
                  ),
                  SizedBox(
                    height:
                        120 *
                        (MediaQuery.textScalerOf(context).scale(11) / 11).clamp(
                          1.0,
                          2.0,
                        ),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: ProductProvider.categoryImages.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final category = ProductProvider.categoryImages.entries
                            .elementAt(index);
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.pushNamed(
                            'categories',
                            queryParameters: {'category': category.key},
                          ),
                          child: SizedBox(
                            width:
                                64 *
                                (MediaQuery.textScalerOf(context).scale(11) /
                                        11)
                                    .clamp(1.0, 2.0),
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    category.value,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  category.key,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Featured Products',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        '${products.length} items',
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ProductGrid(products: products),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

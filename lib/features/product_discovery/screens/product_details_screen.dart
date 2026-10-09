import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/product_model.dart';
import '../../cart_checkout/providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../../cart_checkout/widgets/add_to_cart.dart';
import '../widgets/discovery_ui.dart';
import '../widgets/product_card.dart';

class ProductDetailsScreen extends StatelessWidget {
  const ProductDetailsScreen({super.key, this.productId = ''});
  final String productId;
  @override
  Widget build(BuildContext context) {
    final product = context.watch<ProductProvider>().byId(productId);
    final cart = context.watch<CartProvider>();
    final count = cart.quantity(productId);
    Future<void> copy() async {
      if (product == null) return;
      await Clipboard.setData(
        ClipboardData(
          text:
              'PikZen • ${product.name}\n${product.priceLabel}\n/product-details?id=${Uri.encodeComponent(product.id)}',
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product details copied.')),
        );
      }
    }

    return Scaffold(
      backgroundColor: discoveryBackground,
      appBar: AppBar(
        backgroundColor: discoveryBackground,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => discoveryBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: product == null ? null : _FreshnessPill(product),
        actions: [
          if (product != null) ...[
            IconButton(
              tooltip: 'Copy product details',
              onPressed: copy,
              icon: const Icon(Icons.share_outlined),
            ),
            FavouriteButton(product),
            const SizedBox(width: 8),
          ],
        ],
      ),
      bottomNavigationBar: product == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text(
                    count > 0
                        ? 'View Cart • ${cart.quantity(productId)}'
                        : 'Add to Cart • ${product.priceLabel}',
                  ),
                  onPressed: product.stockQuantity <= 0
                      ? null
                      : () async {
                          if (count == 0 &&
                              !await addToCart(context, product)) {
                            return;
                          }
                          if (context.mounted) context.goNamed('cart');
                        },
                ),
              ),
            ),
      body: product == null
          ? const Center(child: Text('Product not found.'))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CatalogNotice(),
                    _HeroImage(product),
                    const SizedBox(height: 18),
                    _TitleBlock(product),
                    const SizedBox(height: 16),
                    _PriceCard(product),
                    const SizedBox(height: 24),
                    _SectionTitle(
                      const {'Fruits', 'Vegetables'}.contains(product.category)
                          ? 'About the Produce'
                          : 'About the Product',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.description?.isNotEmpty == true
                          ? product.description!
                          : 'Product information is being updated.',
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        height: 1.6,
                      ),
                    ),
                    _Specifications(product),
                    if (product.shopName.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _PickupStoreCard(product),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
    );
  }
}

/// "100% FARM FRESH" style pill shown in the app bar.
class _FreshnessPill extends StatelessWidget {
  const _FreshnessPill(this.product);
  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final fresh = const {'Fruits', 'Vegetables'}.contains(product.category);
    final label = fresh
        ? '100% Farm Fresh'
        : product.isOrganic
        ? 'Certified Organic'
        : product.category;
    if (label.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              fresh || product.isOrganic
                  ? Icons.eco_outlined
                  : Icons.sell_outlined,
              size: 15,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage(this.product);
  final ProductModel product;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: Stack(
      children: [
        ProductImage(product, height: 280, width: double.infinity, hero: true),
        if (product.harvestLabel.isNotEmpty || product.rating != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Row(
              children: [
                if (product.harvestLabel.isNotEmpty)
                  Flexible(
                    child: _ImagePill(
                      leading: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      text: product.harvestLabel,
                    ),
                  ),
                const Spacer(),
                if (product.rating != null)
                  _ImagePill(
                    leading: const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                    text: product.rating!.toStringAsFixed(1),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _ImagePill extends StatelessWidget {
  const _ImagePill({required this.leading, required this.text});
  final Widget leading;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 8),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock(this.product);
  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final source = product.origin.isNotEmpty
        ? 'Sourced from ${product.origin}'
        : product.shopName.isNotEmpty
        ? 'Sold by ${product.shopName}'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text:
                    (product.brand.isNotEmpty
                            ? product.brand
                            : product.category)
                        .toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                ),
              ),
              if (product.brand.isNotEmpty && product.category.isNotEmpty)
                TextSpan(
                  text: '  •  ${product.category}',
                  style: const TextStyle(color: AppColors.secondaryText),
                ),
            ],
          ),
          style: const TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 6),
        Text(
          product.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primaryText,
          ),
        ),
        if (source.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                size: 17,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  source,
                  style: const TextStyle(color: AppColors.secondaryText),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard(this.product);
  final ProductModel product;

  /// "Rs. 95 / 100g" from a unit like "1kg" or "500ml", when it can be read.
  static String? perHundred(ProductModel product) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*(kg|g|l|ml)\b',
      caseSensitive: false,
    ).firstMatch(product.unit);
    if (match == null) return null;
    final amount = double.parse(match[1]!);
    final unit = match[2]!.toLowerCase();
    final base = switch (unit) {
      'kg' || 'l' => amount * 1000,
      _ => amount,
    };
    if (base <= 100) return null;
    final minor = product.priceMinor * 100 / base;
    final suffix = unit == 'kg' || unit == 'g' ? 'g' : 'ml';
    return 'Rs. ${(minor / 100).toStringAsFixed(minor % 100 == 0 ? 0 : 2)} / 100$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final per = perHundred(product);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF3FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: product.priceLabel,
                      style: const TextStyle(
                        fontSize: 30,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (product.unit.isNotEmpty)
                      TextSpan(
                        text: '  / ${product.unit}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                        ),
                      ),
                  ],
                ),
              ),
              if (product.onSale)
                Text(
                  'Rs. ${(product.originalPriceMinor! / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    decoration: TextDecoration.lineThrough,
                  ),
                )
              else if (per != null)
                Text(
                  per,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product.readiness.isNotEmpty &&
                  product.stock != StockStatus.outOfStock)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          product.readiness,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (product.readiness.isEmpty ||
                  product.stock != StockStatus.inStock) ...[
                if (product.readiness.isNotEmpty) const SizedBox(height: 6),
                StockBadge(stock: product.stock),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.primaryText),
  );
}

class _Specifications extends StatelessWidget {
  const _Specifications(this.product);
  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final specs = [
      (Icons.place_outlined, 'Origin', product.origin),
      (Icons.ac_unit_rounded, 'Storage', product.storage),
      (Icons.inventory_2_outlined, 'Packaging', product.packaging),
      (Icons.verified_user_outlined, 'Dietary', product.dietary),
    ].where((spec) => spec.$3.isNotEmpty).toList();
    if (specs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Product Specifications'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final single = MediaQuery.textScalerOf(context).scale(14) > 21;
              final width = single
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (icon, label, value) in specs)
                    SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: const BoxDecoration(
                                color: AppColors.softGreen,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              value,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PickupStoreCard extends StatelessWidget {
  const _PickupStoreCard(this.product);
  final ProductModel product;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.storefront_outlined,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PICKUP STORE',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: .6,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                product.shopName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
              const Text(
                'Choose your pickup time at checkout',
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../cart_checkout/providers/cart_provider.dart';
import '../providers/product_provider.dart';
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
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => discoveryBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Product Details', style: TextStyle(fontSize: 17)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'cart') {
                context.goNamed('cart');
              } else {
                copy();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'cart', child: Text('Open Cart')),
              PopupMenuItem(value: 'copy', child: Text('Copy product details')),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Image.asset(AppAssets.logo, width: 28),
          ),
        ],
      ),
      bottomNavigationBar: product == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 116,
                      child: QuantityControl(product: product),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: Text(
                        count > 0
                            ? 'View Cart • ${cart.quantity(productId)}'
                            : 'Add to Cart • ${product.priceLabel}',
                      ),
                      onPressed: product.stockQuantity <= 0
                          ? null
                          : () {
                              if (count == 0 && !cart.add(product)) return;
                              context.goNamed('cart');
                            },
                    ),
                  ],
                ),
              ),
            ),
      body: product == null
          ? const Center(child: Text('Product not found.'))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CatalogNotice(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.isOrganic
                                ? 'ORGANIC • ${product.category}'
                                : product.category,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy product details',
                          onPressed: copy,
                          icon: const Icon(Icons.share_outlined),
                        ),
                        FavouriteButton(product),
                      ],
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        children: [
                          ProductImage(
                            product,
                            height: 260,
                            width: double.infinity,
                          ),
                          if (product.harvestLabel.isNotEmpty ||
                              product.rating != null)
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                children: [
                                  if (product.harvestLabel.isNotEmpty)
                                    Chip(label: Text(product.harvestLabel)),
                                  if (product.rating != null)
                                    Chip(
                                      avatar: const Icon(
                                        Icons.star,
                                        color: AppColors.accent,
                                        size: 16,
                                      ),
                                      label: Text('${product.rating}'),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (product.brand.isNotEmpty)
                      Text(
                        product.brand.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                        ),
                      ),
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (product.shopName.isNotEmpty)
                      Text(
                        'Sourced from ${product.shopName}',
                        style: const TextStyle(color: AppColors.secondaryText),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF3FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.priceLabel,
                                style: const TextStyle(
                                  fontSize: 28,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(product.unit),
                              if (product.onSale)
                                Text(
                                  'Rs. ${(product.originalPriceMinor! / 100).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StockBadge(stock: product.stock),
                              if (product.readiness.isNotEmpty)
                                Text(product.readiness),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'About the Product',
                      style: Theme.of(context).textTheme.titleMedium,
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
                    const SizedBox(height: 24),
                    if ([
                      product.origin,
                      product.storage,
                      product.packaging,
                      product.dietary,
                    ].any((v) => v.isNotEmpty)) ...[
                      Text(
                        'Product Specifications',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) => Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final entry in {
                              'Origin': product.origin,
                              'Storage': product.storage,
                              'Packaging': product.packaging,
                              'Dietary': product.dietary,
                            }.entries)
                              if (entry.value.isNotEmpty)
                                SizedBox(
                                  width:
                                      MediaQuery.textScalerOf(context)
                                              .scale(14) >
                                          21
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth - 12) / 2,
                                  child: Card(
                                    margin: EdgeInsets.zero,
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.verified_outlined,
                                            color: AppColors.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            entry.key,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                          Text(
                                            entry.value,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                    if (product.shopName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.storefront_outlined),
                            title: Text(product.shopName),
                            subtitle: const Text(
                              'Pickup details are confirmed at checkout.',
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
    );
  }
}

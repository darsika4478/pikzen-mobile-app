import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/product_model.dart';
import '../providers/product_provider.dart';
import 'product_card.dart';

const discoveryBackground = Color(0xFFF8F9FF);

class DiscoveryHeader extends StatelessWidget implements PreferredSizeWidget {
  const DiscoveryHeader(this.title, {super.key});
  final String title;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 64,
    automaticallyImplyLeading: false,
    leading: const Icon(
      Icons.shopping_basket_outlined,
      color: AppColors.primary,
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PIKZEN LOCAL',
          style: TextStyle(fontSize: 9, color: AppColors.primary),
        ),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
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
        child: Image.asset(AppAssets.logo, width: 28, height: 28),
      ),
    ],
  );
}

class ProductImage extends StatelessWidget {
  const ProductImage(
    this.product, {
    super.key,
    this.height = 100,
    this.width,
    this.fit = BoxFit.cover,
  });
  final ProductModel product;
  final double height;
  final double? width;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
      height: height,
      width: width,
      color: AppColors.softGreen,
      child: const Center(
        child: Icon(Icons.shopping_basket_outlined, color: AppColors.primary),
      ),
    );
    final path = product.imageUrl;
    if (path == null || path.isEmpty) return fallback();
    final uri = Uri.tryParse(path);
    if (uri?.scheme == 'https') {
      return Image.network(
        path,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    if (!path.startsWith('assets/')) return fallback();
    return Image.asset(
      path,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, _, _) => fallback(),
    );
  }
}

class FavouriteButton extends StatelessWidget {
  const FavouriteButton(this.product, {super.key});
  final ProductModel product;
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final saved = provider.isFavourite(product.id);
    return IconButton(
      tooltip: saved
          ? 'Remove ${product.name} from favourites'
          : 'Favourite ${product.name}',
      onPressed: () => provider.toggleFavourite(product.id),
      icon: Icon(
        saved ? Icons.favorite : Icons.favorite_border,
        size: 21,
        color: saved ? AppColors.error : AppColors.secondaryText,
      ),
    );
  }
}

class CatalogNotice extends StatelessWidget {
  const CatalogNotice({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    if (!provider.isDemo && provider.error == null && !provider.loading) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          if (provider.loading) const LinearProgressIndicator(),
          if (provider.isDemo)
            const Text(
              'Demo catalog • live inventory is not available yet.',
              style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
            ),
          if (provider.error != null)
            TextButton.icon(
              onPressed: provider.retry,
              icon: const Icon(Icons.refresh),
              label: Text(provider.error!),
            ),
        ],
      ),
    );
  }
}

class ProductListCard extends StatelessWidget {
  const ProductListCard(this.product, {super.key, this.addLabel = '+ Add'});
  final String addLabel;
  final ProductModel product;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.pushNamed(
        'product-details',
        queryParameters: {'id': product.id},
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final large =
                MediaQuery.textScalerOf(context).scale(14) > 21 ||
                constraints.maxWidth < 230;
            final image = ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ProductImage(
                product,
                width: large ? double.infinity : 90,
                height: large ? 160 : 108,
              ),
            );
            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.shopName.isEmpty
                                ? product.category
                                : product.shopName,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FavouriteButton(product),
                  ],
                ),
                Text(
                  product.unit,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 5),
                StockBadge(stock: product.stock),
                const SizedBox(height: 8),
                Text(
                  product.priceLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                QuantityControl(product: product, addLabel: addLabel),
              ],
            );
            return large
                ? Column(children: [image, const SizedBox(height: 10), info])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      image,
                      const SizedBox(width: 12),
                      Expanded(child: info),
                    ],
                  );
          },
        ),
      ),
    ),
  );
}

void discoveryBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.goNamed('customer-home');
  }
}

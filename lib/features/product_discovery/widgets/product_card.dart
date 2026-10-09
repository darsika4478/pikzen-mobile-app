import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/product_model.dart';
import '../../cart_checkout/providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../../cart_checkout/widgets/add_to_cart.dart';
import 'discovery_ui.dart';
import '../../../shared/widgets/animations.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});
  final ProductModel product;
  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.pushNamed(
          'product-details',
          queryParameters: {'id': product.id},
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ProductImage(
                      product,
                      width: double.infinity,
                      height: 128,
                      hero: true,
                    ),
                  ),
                  Positioned(
                    left: 4,
                    top: 4,
                    child: StockBadge(stock: product.stock),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton.filledTonal(
                      tooltip: products.isFavourite(product.id)
                          ? 'Remove ${product.name} from favourites'
                          : 'Favourite ${product.name}',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        minimumSize: const Size(36, 36),
                        padding: const EdgeInsets.all(6),
                      ),
                      onPressed: () => products.toggleFavourite(product.id),
                      icon: Icon(
                        products.isFavourite(product.id)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: products.isFavourite(product.id)
                            ? AppColors.error
                            : AppColors.secondaryText,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                product.category,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.secondaryText,
                ),
              ),
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                product.unit,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.secondaryText,
                ),
              ),
              const Spacer(),
              Text(
                product.priceLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              QuantityControl(product: product),
            ],
          ),
        ),
      ),
    );
  }
}

class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.stock});
  final StockStatus stock;
  @override
  Widget build(BuildContext context) {
    final color = switch (stock) {
      StockStatus.inStock => AppColors.success,
      StockStatus.lowStock => AppColors.warning,
      StockStatus.outOfStock => AppColors.error,
    };
    final label = switch (stock) {
      StockStatus.inStock => 'In Stock',
      StockStatus.lowStock => 'Low Stock',
      StockStatus.outOfStock => 'Out of Stock',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: .14), Colors.white),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class QuantityControl extends StatelessWidget {
  const QuantityControl({
    super.key,
    required this.product,
    this.addLabel = '+ Add',
  });
  final String addLabel;
  final ProductModel product;
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final count = cart.quantity(product.id);
    if (count == 0) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: product.stock == StockStatus.outOfStock
              ? null
              : () => addToCart(context, product),
          child: Text(addLabel, style: const TextStyle(fontSize: 12)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Decrease ${product.name}',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
            padding: EdgeInsets.zero,
            onPressed: () => cart.decrease(product.id),
            icon: const Icon(Icons.remove, size: 17),
          ),
          Flexible(child: Text('$count', textAlign: TextAlign.center)),
          IconButton(
            tooltip: 'Increase ${product.name}',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
            padding: EdgeInsets.zero,
            onPressed: count < product.availableQuantity
                ? () => cart.add(product)
                : null,
            icon: const Icon(Icons.add, size: 17),
          ),
        ],
      ),
    );
  }
}

class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key, required this.products});
  final List<ProductModel> products;
  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('No products found.')),
      );
    }
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: constraints.maxWidth < 300 || scale > 1.5
              ? 1
              : constraints.maxWidth > 650
              ? 3
              : 2,
          mainAxisExtent: 330 + (scale - 1) * 130,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: products.length,
        itemBuilder: (_, index) => FadeSlideIn(
          key: ValueKey(products[index].id),
          index: index,
          child: ProductCard(product: products[index]),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/cart_item_model.dart';
import '../../../models/product_model.dart';
import '../../product_discovery/widgets/discovery_ui.dart';
import '../../product_discovery/widgets/product_card.dart';
import '../providers/cart_provider.dart';

// Checkout has no fee or delivery rule yet. Keep these values explicit.
const _serviceFeeMinor = 0;
const _deliveryFeeMinor = 0;

String _rupees(int minor) {
  final whole = (minor ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return 'Rs. $whole.${(minor % 100).toString().padLeft(2, '0')}';
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: .05),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
  ],
);

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _promoController = TextEditingController();

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  void _applyPromo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _promoController.text.trim().isEmpty
              ? 'Enter a promo code first.'
              : 'Promo codes are not available yet.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final items = cart.items;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(AppAssets.logo, width: 30, height: 30),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const _DeliveryBanner(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Review Your Basket',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${items.length} ${items.length == 1 ? 'Item' : 'Items'}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty) const _EmptyCart(),
            for (final item in items) ...[
              _CartItemCard(item: item),
              const SizedBox(height: 10),
            ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PromoCard(controller: _promoController, onApply: _applyPromo),
              const SizedBox(height: 12),
              _OrderSummary(
                count: items.length,
                subtotalMinor: cart.totalMinor,
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: items.isEmpty
                    ? null
                    : () => context.pushNamed('checkout'),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Proceed to Checkout'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 12,
                  color: AppColors.secondaryText,
                ),
                SizedBox(width: 4),
                Text(
                  'Secure checkout',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryBanner extends StatelessWidget {
  const _DeliveryBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF9AEDAB),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: AppColors.primary,
          child: Icon(
            Icons.local_shipping_outlined,
            color: Colors.white,
            size: 21,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Free Local Delivery Unlocked!',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              SizedBox(height: 2),
              Text(
                'Your basket supports local family farms.',
                style: TextStyle(fontSize: 11, color: AppColors.primaryText),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: AppColors.primary),
      ],
    ),
  );
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
    decoration: _cardDecoration(),
    child: Column(
      children: [
        const Icon(
          Icons.shopping_basket_outlined,
          size: 60,
          color: AppColors.primary,
        ),
        const SizedBox(height: 12),
        Text(
          'Your cart is empty',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Find something fresh to add to your basket.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        OutlinedButton(
          onPressed: () => context.goNamed('customer-home'),
          child: const Text('Continue Shopping'),
        ),
      ],
    ),
  );
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({required this.item});
  final CartItemModel item;

  Future<void> _remove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Item?'),
        content: const Text('Remove this item from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<CartProvider>().remove(item.product.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: _CartProductImage(product),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      height: 28,
                      child: IconButton(
                        tooltip: 'Remove ${product.name}',
                        padding: EdgeInsets.zero,
                        onPressed: () => _remove(context),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.secondaryText,
                          size: 19,
                        ),
                      ),
                    ),
                  ],
                ),
                if (product.unit.isNotEmpty)
                  Text(
                    product.unit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final price = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _rupees(product.priceMinor),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        StockBadge(stock: product.stock),
                      ],
                    );
                    final quantity = _CartQuantity(item: item);
                    return constraints.maxWidth < 170
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              price,
                              const SizedBox(height: 6),
                              quantity,
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: price),
                              quantity,
                            ],
                          );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartProductImage extends StatelessWidget {
  const _CartProductImage(this.product);
  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    if (product.imageUrl?.startsWith('assets/') == true) {
      return ProductImage(product, width: 74, height: 76);
    }
    final name = product.name.toLowerCase();
    final localPath = name.contains('apple')
        ? 'assets/images/Apples Product.png'
        : product.category == 'Bakery'
        ? 'assets/images/Bakery.png'
        : name.contains('milk')
        ? 'assets/images/Milk Product.png'
        : null;
    if (localPath != null) {
      return Image.asset(localPath, width: 74, height: 76, fit: BoxFit.cover);
    }
    return ProductImage(product, width: 74, height: 76);
  }
}

class _CartQuantity extends StatelessWidget {
  const _CartQuantity({required this.item});
  final CartItemModel item;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(
          'Decrease ${item.product.name}',
          Icons.remove,
          item.quantity > 1 ? () => cart.decrease(item.product.id) : null,
        ),
        SizedBox(
          width: 26,
          child: Text('${item.quantity}', textAlign: TextAlign.center),
        ),
        _button('Increase ${item.product.name}', Icons.add, () {
          if (!cart.add(item.product)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Only ${item.product.stockQuantity} items available in stock.',
                ),
              ),
            );
          }
        }, filled: true),
      ],
    );
  }

  Widget _button(
    String tooltip,
    IconData icon,
    VoidCallback? action, {
    bool filled = false,
  }) => SizedBox(
    width: 28,
    height: 28,
    child: IconButton(
      tooltip: tooltip,
      onPressed: action,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: filled ? AppColors.primary : AppColors.background,
        foregroundColor: filled ? Colors.white : AppColors.primaryText,
        disabledForegroundColor: AppColors.secondaryText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      icon: Icon(icon, size: 17),
    ),
  );
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.controller, required this.onApply});
  final TextEditingController controller;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Got a Promo Code?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'e.g. FRESHPICK',
                  prefixIcon: Icon(Icons.local_offer_outlined, size: 18),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: onApply, child: const Text('Apply')),
          ],
        ),
      ],
    ),
  );
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.count, required this.subtotalMinor});
  final int count;
  final int subtotalMinor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Summary',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        _row('Subtotal ($count Items)', _rupees(subtotalMinor)),
        const SizedBox(height: 8),
        _row('Service & Handling Fee', _rupees(_serviceFeeMinor)),
        const SizedBox(height: 8),
        _row('Estimated Delivery', 'FREE', green: true),
        const Divider(height: 28),
        _row(
          'Total',
          _rupees(subtotalMinor + _serviceFeeMinor + _deliveryFeeMinor),
          bold: true,
          green: true,
        ),
      ],
    ),
  );

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    bool green = false,
  }) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: bold ? 15 : 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        value,
        style: TextStyle(
          color: green ? AppColors.primary : AppColors.primaryText,
          fontSize: bold ? 17 : 12,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    ],
  );
}

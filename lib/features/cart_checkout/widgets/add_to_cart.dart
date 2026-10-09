import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/product_model.dart';
import '../providers/cart_provider.dart';

/// Adds [product] to the cart, explaining why it cannot be added when the
/// cart holds another shop's items or already has the maximum products.
/// Returns true when the product is in the cart afterwards.
Future<bool> addToCart(BuildContext context, ProductModel product) async {
  final cart = context.read<CartProvider>();
  final messenger = ScaffoldMessenger.of(context);
  switch (cart.blockFor(product)) {
    case CartBlock.otherShop:
      final current = cart.shopName?.trim();
      final next = product.shopName.trim();
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Start a new cart?'),
          content: Text(
            'Pickup orders come from one shop at a time. Your cart has items '
            'from ${current == null || current.isEmpty ? 'another shop' : current}. '
            'Clear it and add ${product.name}'
            '${next.isEmpty ? '' : ' from $next'}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep Current Cart'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Start New Cart'),
            ),
          ],
        ),
      );
      if (replace != true) return false;
      final added = cart.replaceWith(product);
      if (added) _added(messenger, product);
      return added;
    case CartBlock.tooManyProducts:
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'An order can include up to ${CartProvider.maxProducts} '
              'different products. Check out first, then start a new order.',
            ),
          ),
        );
      return false;
    case null:
      final added = cart.add(product);
      if (added) _added(messenger, product);
      return added;
  }
}

void _added(ScaffoldMessengerState messenger, ProductModel product) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        duration: const Duration(seconds: 1),
      ),
    );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import '../../product_discovery/widgets/product_card.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: cart.items.isEmpty
          ? const Center(child: Text('Your cart is empty.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final item in cart.items)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                item.product.imageUrl!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(item.product.priceLabel),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove ${item.product.name}',
                                onPressed: () => cart.remove(item.product.id),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          QuantityControl(product: item.product),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Total: Rs. ${(cart.totalMinor / 100).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
    );
  }
}

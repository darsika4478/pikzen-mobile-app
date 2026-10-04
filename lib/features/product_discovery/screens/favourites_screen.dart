import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../cart_checkout/providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../widgets/discovery_ui.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});
  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  String _filter = 'All Items';
  @override
  Widget build(BuildContext context) {
    final saved = context.watch<ProductProvider>().favourites;
    final visible = saved
        .where(
          (p) =>
              _filter == 'All Items' ||
              (_filter == 'In Stock' ? p.stockQuantity > 0 : p.onSale),
        )
        .toList();
    final cart = context.watch<CartProvider>();
    final canAdd = saved.any((p) => cart.quantity(p.id) < p.stockQuantity);
    return Scaffold(
      backgroundColor: discoveryBackground,
      appBar: const DiscoveryHeader('Favourites'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Favourites  •  ${saved.length} saved',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_shopping_cart, size: 17),
                    label: const Text('Add All to Cart'),
                    onPressed: !canAdd
                        ? null
                        : () {
                            var added = 0;
                            for (final product in saved) {
                              if (cart.add(product)) added++;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Added $added items. Unavailable items were skipped.',
                                ),
                              ),
                            );
                          },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final name in ['All Items', 'In Stock', 'Special Deals'])
                    ChoiceChip(
                      label: Text(name),
                      selected: _filter == name,
                      onSelected: (_) => setState(() => _filter = name),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const CatalogNotice(),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No favourites to show. Save products using the heart.',
                  ),
                ),
              for (final product in visible)
                ProductListCard(product, addLabel: '+ Cart'),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mock_shop_product.dart';
import '../widgets/products_header.dart';
import '../widgets/product_search_bar.dart';
import '../widgets/product_list_card.dart';
import '../widgets/dashboard_bottom_nav.dart';

/// Merchant products preview with local search only.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _search = '';
  void _openForm([MockShopProduct? product]) {
    FocusScope.of(context).unfocus();
    context.pushNamed(
      'add-edit-product',
      queryParameters: {
        if (product != null) 'product': product.visualType.name,
      },
    );
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('shop-dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = mockShopProducts
        .where(
          (product) =>
              product.name.toLowerCase().contains(_search.trim().toLowerCase()),
        )
        .toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                ProductsHeader(onBack: _back, onAdd: () => _openForm()),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: TextButton.icon(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        context.pushNamed('inventory-stock');
                      },
                      icon: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: const Text(
                        'Inventory & Stock',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ProductSearchBar(
                    onChanged: (value) => setState(() => _search = value),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: products.isEmpty
                      ? const Center(
                          child: Text(
                            'No products found',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        )
                      : ListView.separated(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: products.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => ProductListCard(
                            product: products[index],
                            onSelected: () => _openForm(products[index]),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: DashboardBottomNav(
        selectedIndex: 2,
        onSelected: (index) {
          FocusScope.of(context).unfocus();
          switch (index) {
            case 0:
              context.goNamed('shop-dashboard');
            case 1:
              context.pushNamed('incoming-orders');
            case 2:
              break;
            case 3:
              context.pushNamed('shop-profile');
          }
        },
      ),
    );
  }
}

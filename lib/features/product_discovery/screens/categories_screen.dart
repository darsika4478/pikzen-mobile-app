import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/product_provider.dart';
import '../widgets/discovery_ui.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key, this.category});
  final String? category;
  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>();
    final entries = ProductProvider.categoryImages.entries.toList();
    void search(String query) =>
        context.pushNamed('search', queryParameters: {'q': query});
    return Scaffold(
      backgroundColor: discoveryBackground,
      appBar: const DiscoveryHeader('Categories'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => discoveryBack(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Text(
                    'Categories',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  Chip(
                    label: Text(
                      '${entries.length} Main Aisles',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
              TextField(
                textInputAction: TextInputAction.search,
                onSubmitted: search,
                decoration: const InputDecoration(
                  hintText: 'Search departments or items',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 16),
              const CatalogNotice(),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wideText =
                      MediaQuery.textScalerOf(context).scale(14) > 21;
                  final columns = wideText || constraints.maxWidth < 280
                      ? 1
                      : 2;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final entry in entries)
                        SizedBox(
                          width: width,
                          child: Card(
                            margin: EdgeInsets.zero,
                            elevation: 0,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => context.pushNamed(
                                'search',
                                queryParameters: {'category': entry.key},
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Image.asset(
                                    entry.value,
                                    height: width * .75,
                                    width: width,
                                    fit: BoxFit.cover,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                entry.key,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${products.matching(category: entry.key).length} items available',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.secondaryText,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.softGreen,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            ProductProvider.categoryTags[entry
                                                .key]!,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

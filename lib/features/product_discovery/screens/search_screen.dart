import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/product_model.dart';
import '../providers/product_provider.dart';
import '../widgets/discovery_ui.dart';
import '../../../shared/widgets/animations.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.query = '', this.category});
  final String query;
  final String? category;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _query = TextEditingController(
    text: widget.query,
  );
  late String? _category = widget.category == null
      ? null
      : ProductModel.canonicalCategory(widget.category!);
  bool _organic = false;
  bool _inStock = false;
  String _sort = 'Relevance';
  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _query.text = widget.query;
    if (oldWidget.category != widget.category) {
      _category = widget.category == null
          ? null
          : ProductModel.canonicalCategory(widget.category!);
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final results = provider
        .matching(query: _query.text, category: _category)
        .where(
          (p) =>
              (!_organic || p.isOrganic) && (!_inStock || p.stockQuantity > 0),
        )
        .toList();
    if (_sort == 'Price: Low to High') {
      results.sort((a, b) => a.priceMinor.compareTo(b.priceMinor));
    }
    if (_sort == 'Price: High to Low') {
      results.sort((a, b) => b.priceMinor.compareTo(a.priceMinor));
    }
    if (_sort == 'Name') results.sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      backgroundColor: discoveryBackground,
      appBar: const DiscoveryHeader('Search Results'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => discoveryBack(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _query,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search groceries',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'Clear search',
                          onPressed: () => setState(_query.clear),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Filter available stock',
                    onPressed: () => setState(() => _inStock = !_inStock),
                    icon: Icon(_inStock ? Icons.filter_alt : Icons.tune),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _category == null,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                    ),
                    for (final name in ProductProvider.categoryImages.keys)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(name),
                          selected: _category == name,
                          onSelected: (_) => setState(() => _category = name),
                        ),
                      ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Organic Only'),
                    selected: _organic,
                    onSelected: (v) => setState(() => _organic = v),
                  ),
                  if (_inStock)
                    InputChip(
                      label: const Text('In Stock'),
                      onDeleted: () => setState(() => _inStock = false),
                    ),
                ],
              ),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Showing ${results.length} results${_query.text.isEmpty ? '' : ' for "${_query.text}"'}',
                  ),
                  DropdownButton<String>(
                    value: _sort,
                    items: [
                      for (final name in [
                        'Relevance',
                        'Price: Low to High',
                        'Price: High to Low',
                        'Name',
                      ])
                        DropdownMenuItem(
                          value: name,
                          child: Text(
                            name == 'Price: Low to High'
                                ? 'Price ↑'
                                : name == 'Price: High to Low'
                                ? 'Price ↓'
                                : name,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _sort = v!),
                  ),
                ],
              ),
              const CatalogNotice(),
              if (results.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No products found. Try another search or filter.',
                  ),
                ),
              for (final (index, product) in results.indexed)
                FadeSlideIn(
                  key: ValueKey(product.id),
                  index: index,
                  child: ProductListCard(product),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

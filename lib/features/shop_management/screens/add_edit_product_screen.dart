import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firestore_service.dart';
import '../models/mock_shop_product.dart';
import '../widgets/dashboard_bottom_nav.dart';
import '../widgets/product_form_controls.dart';
import '../widgets/product_image_preview.dart';

class AddEditProductScreen extends StatefulWidget {
  const AddEditProductScreen({super.key, this.product, this.service});
  final MockShopProduct? product;
  final FirestoreService? service;
  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _description;
  String? _category;
  late int _quantity;
  bool _saving = false;
  late final FirestoreService _service = widget.service ?? FirestoreService();
  bool get _editing => widget.product != null;
  static const _categories = [
    'Fruits',
    'Vegetables',
    'Dairy',
    'Bakery',
    'Beverages',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.product?.name ?? '');
    _price = TextEditingController(
      text: widget.product?.price.replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
    );
    _description = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _category = widget.product?.category;
    _quantity = widget.product?.stockQuantity ?? 0;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('product-management');
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_price.text.trim());
    setState(() => _saving = true);
    try {
      await _service.saveShopProduct(
        productId: _editing ? widget.product!.id : null,
        name: _name.text,
        category: _category!,
        priceMinor: (amount * 100).round(),
        stockQuantity: _quantity,
        description: _description.text,
        unit: widget.product?.unit ?? '',
        imageUrl: widget.product?.imageUrl,
        lowStockThreshold: widget.product?.lowStockThreshold ?? 5,
      );
      if (!mounted) return;
      _message(
        _editing ? 'Product changes saved' : 'Product added successfully',
      );
      context.goNamed('product-management');
    } catch (error) {
      if (mounted) _message('Product could not be saved: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text(
          'Are you sure you want to delete ${widget.product!.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.rejectRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _saving) return;
    setState(() => _saving = true);
    try {
      await _service.deactivateShopProduct(widget.product!.id);
      if (!mounted) return;
      _message('Product deactivated');
      context.goNamed('product-management');
    } catch (error) {
      if (mounted) _message('Product could not be deactivated: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                ProductFormHeader(
                  editing: _editing,
                  onBack: _back,
                  onDelete: _delete,
                ),
                if (!_editing)
                  const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: ProductImagePreview(
                              product: widget.product,
                              onChange: () => _message(
                                'Product image upload is not available yet.',
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ProductFormField(
                            label: 'PRODUCT NAME',
                            child: TextFormField(
                              controller: _name,
                              style: const TextStyle(fontSize: 12),
                              decoration: _fieldDecoration(
                                _editing
                                    ? 'Enter product name'
                                    : 'e.g. Fresh Red Apple',
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Enter a product name'
                                  : null,
                            ),
                          ),
                          ProductFormField(
                            label: 'CATEGORY',
                            child: DropdownButtonFormField<String>(
                              initialValue: _category,
                              isExpanded: true,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primaryText,
                              ),
                              decoration: _fieldDecoration('Select category'),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: AppColors.secondaryText,
                              ),
                              items:
                                  (_editing
                                          ? _categories
                                          : [
                                              ..._categories.take(5),
                                              'Snacks',
                                              'Other',
                                            ])
                                      .map(
                                        (value) => DropdownMenuItem(
                                          value: value,
                                          child: Text(value),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) =>
                                  setState(() => _category = value),
                              validator: (value) =>
                                  value == null ? 'Select a category' : null,
                            ),
                          ),
                          ProductFormField(
                            label: 'PRICE (RS)',
                            child: TextFormField(
                              controller: _price,
                              style: const TextStyle(fontSize: 12),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _fieldDecoration('0.00')
                                  .copyWith(prefixText: 'Rs   '),
                              validator: (value) {
                                final number = double.tryParse(
                                  value?.trim() ?? '',
                                );
                                return number == null ||
                                        !number.isFinite ||
                                        number <= 0 ||
                                        !RegExp(r'^\d+(\.\d{1,2})?$')
                                            .hasMatch(value!.trim())
                                    ? 'Enter a price greater than 0'
                                    : null;
                              },
                            ),
                          ),
                          ProductFormField(
                            label: 'STOCK QUANTITY',
                            child: StockQuantitySelector(
                              outlinedControls: !_editing,
                              quantity: _quantity,
                              onDecrease: () => setState(() {
                                if (_quantity > 0) _quantity--;
                              }),
                              onIncrease: () => setState(() => _quantity++),
                            ),
                          ),
                          ProductFormField(
                            label: 'DESCRIPTION',
                            child: TextFormField(
                              controller: _description,
                              minLines: _editing ? 3 : 4,
                              maxLines: _editing ? 3 : 4,
                              textAlignVertical: TextAlignVertical.top,
                              style: const TextStyle(fontSize: 12, height: 1.5),
                              decoration: _fieldDecoration(
                                'Enter product description',
                              ),
                            ),
                          ),
                          SizedBox(height: _editing ? 2 : 40),
                          ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: Text(
                              _saving
                                  ? 'Saving...'
                                  : _editing
                                  ? 'Save Changes'
                                  : 'Add Product',
                            ),
                          ),
                          if (_editing) ...[
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: _saving ? null : _delete,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppColors.surface,
                                foregroundColor: AppColors.rejectRed,
                                side: const BorderSide(
                                  color: AppColors.rejectBorder,
                                ),
                                minimumSize: const Size(0, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('Deactivate Product'),
                            ),
                          ],
                        ],
                      ),
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
              _back();
            case 3:
              context.pushNamed('shop-profile');
          }
        },
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    final decoration = productFieldDecoration(hint);
    return _editing
        ? decoration
        : decoration.copyWith(
            filled: true,
            fillColor: AppColors.surface,
            errorStyle: const TextStyle(fontSize: 10),
          );
  }
}

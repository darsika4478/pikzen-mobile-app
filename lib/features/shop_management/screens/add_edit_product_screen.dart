import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firestore_service.dart';
import '../../../models/product_model.dart';
import '../../../shared/widgets/profile_photo.dart';
import '../../product_discovery/providers/product_provider.dart';
import '../models/mock_shop_product.dart';
import '../widgets/dashboard_bottom_nav.dart';
import '../widgets/product_form_controls.dart';
import '../widgets/product_image_preview.dart';

class AddEditProductScreen extends StatefulWidget {
  const AddEditProductScreen({
    super.key,
    this.product,
    this.service,
    this.photoPicker,
  });
  final MockShopProduct? product;
  final FirestoreService? service;

  /// Returns picked, already-resized image bytes; defaults to [ImagePicker].
  final Future<Uint8List?> Function(ImageSource source)? photoPicker;
  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _description;
  late final TextEditingController _unit;
  String? _category;
  String? _imageUrl;
  bool _pickingPhoto = false;
  late int _quantity;
  bool _saving = false;
  late final FirestoreService _service = widget.service ?? FirestoreService();
  bool get _editing => widget.product != null;

  /// The customer catalogue's categories, plus a legacy value if editing.
  List<String> get _categories => [
    ...ProductProvider.categoryImages.keys,
    if (_category != null &&
        !ProductProvider.categoryImages.containsKey(_category))
      _category!,
  ];

  /// Upper bound for an inline product photo; matches firestore.rules.
  static const _maxPhotoLength = 400000;

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
    _unit = TextEditingController(text: widget.product?.unit ?? '');
    final category = widget.product?.category;
    _category = category == null || category.isEmpty
        ? null
        : ProductModel.canonicalCategory(category);
    _quantity = widget.product?.stockQuantity ?? 0;
    _imageUrl = widget.product?.imageUrl;
  }

  Future<void> _choosePhoto() async {
    if (_pickingPhoto || _saving) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;
    setState(() => _pickingPhoto = true);
    try {
      final Uint8List? bytes;
      if (widget.photoPicker != null) {
        bytes = await widget.photoPicker!(source);
      } else {
        final file = await ImagePicker().pickImage(
          source: source,
          maxWidth: 640,
          maxHeight: 640,
          imageQuality: 70,
        );
        bytes = await file?.readAsBytes();
      }
      if (!mounted || bytes == null) return;
      final encoded = ProfilePhotoData.encode(bytes);
      if (encoded == null) {
        _message('Choose a JPEG or PNG photo.');
      } else if (encoded.length > _maxPhotoLength) {
        _message('That photo is too large. Try another one.');
      } else {
        setState(() => _imageUrl = encoded);
      }
    } on PlatformException {
      _message(
        source == ImageSource.camera
            ? 'Camera access is needed to take a photo. Allow it in Settings.'
            : 'Photo access is needed to choose a picture. Allow it in Settings.',
      );
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _unit.dispose();
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
        unit: _unit.text,
        imageUrl: _imageUrl ?? '',
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
            constraints: const BoxConstraints(maxWidth: 640),
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
                              imageUrl: _imageUrl,
                              busy: _pickingPhoto,
                              onChange: _choosePhoto,
                              onRemove: () => setState(() => _imageUrl = ''),
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
                              items: _categories
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
                            label: 'UNIT',
                            child: TextFormField(
                              controller: _unit,
                              style: const TextStyle(fontSize: 12),
                              textCapitalization: TextCapitalization.none,
                              decoration: _fieldDecoration(
                                'e.g. 1kg bag, 500ml, Pack of 10',
                              ),
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

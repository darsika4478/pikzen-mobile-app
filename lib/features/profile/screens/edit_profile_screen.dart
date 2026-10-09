import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/order_service.dart';
import '../../../core/utils/validators.dart';
import '../../../models/order_model.dart';
import '../../../shared/widgets/profile_photo.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/merchant_edit_profile_view.dart';

typedef EditProfileIdentity = ({
  String uid,
  String? email,
  String? displayName,
  String? photoUrl,
  bool emailVerified,
});

/// Edits the signed-in customer's safe profile fields in users/{uid}.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    this.profileLoader,
    this.profileWriter,
    this.ordersForCustomer,
    this.identityForTesting,
    this.photoPicker,
  }) : isShopPartner = false;

  const EditProfileScreen.shopPartner({super.key})
    : isShopPartner = true,
      profileLoader = null,
      profileWriter = null,
      ordersForCustomer = null,
      identityForTesting = null,
      photoPicker = null;

  final bool isShopPartner;

  /// Test seams; the application route constructs this screen without overrides.
  final Future<Map<String, dynamic>?> Function(String uid)? profileLoader;
  final Future<void> Function(String uid, Map<String, Object?> changes)?
  profileWriter;
  final Stream<List<OrderModel>> Function(String uid)? ordersForCustomer;
  final EditProfileIdentity? identityForTesting;

  /// Returns picked image bytes, already resized; defaults to [ImagePicker].
  final Future<Uint8List?> Function(ImageSource source)? photoPicker;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _uid;
  bool _loading = false;
  bool _loaded = false;
  bool _missing = false;
  bool _loadError = false;
  bool _saving = false;
  String _originalName = '';
  String _originalPhone = '';
  bool _originalSms = false;
  bool _originalPaperless = false;
  bool _sms = false;
  bool _paperless = false;
  String _photoUrl = '';
  bool _savingPhoto = false;
  DateTime? _createdAt;
  Stream<List<OrderModel>>? _orders;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EditProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileLoader != widget.profileLoader ||
        oldWidget.ordersForCustomer != widget.ordersForCustomer) {
      _uid = null;
    }
  }

  EditProfileIdentity? _identity(BuildContext context) {
    if (Firebase.apps.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return (
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
        emailVerified: user.emailVerified,
      );
    }
    final supplied = widget.identityForTesting;
    if (supplied != null) return supplied;
    final user = context.read<AuthProvider>().user;
    if (user == null) return null;
    return (
      uid: user.id,
      email: user.email,
      displayName: user.name,
      photoUrl: null,
      emailVerified: false,
    );
  }

  void _startLoading(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    _loaded = false;
    _loading = true;
    _missing = false;
    _loadError = false;
    _orders =
        widget.ordersForCustomer?.call(uid) ??
        (Firebase.apps.isEmpty
            ? Stream<List<OrderModel>>.value(const [])
            : OrderService().forCustomer(uid));
    final load =
        widget.profileLoader?.call(uid) ??
        (Firebase.apps.isEmpty
            ? Future<Map<String, dynamic>?>.value(null)
            : FirestoreService().database
                  .collection('users')
                  .doc(uid)
                  .get()
                  .then((document) => document.data()));
    load
        .then((data) {
          if (!mounted || _uid != uid) return;
          setState(() {
            _loading = false;
            if (data == null || data['role'] != 'customer') {
              _missing = true;
              return;
            }
            _originalName = _string(data['fullName']).isNotEmpty
                ? _string(data['fullName'])
                : _string(data['name']);
            _originalPhone = _string(data['phone']);
            final prefs = data['preferences'];
            final preferences = prefs is Map ? prefs : const {};
            _originalSms = preferences['readyForPickupSms'] == true;
            _originalPaperless = preferences['paperlessInvoices'] == true;
            _sms = _originalSms;
            _paperless = _originalPaperless;
            _name.text = _originalName;
            _phone.text = _originalPhone;
            _photoUrl = _firstText([
              _string(data['profileImageUrl']),
              _string(data['photoUrl']),
            ]);
            final created = data['createdAt'];
            _createdAt = created is Timestamp
                ? created.toDate()
                : created is DateTime
                ? created
                : null;
            _loaded = true;
          });
        })
        .catchError((Object _) {
          if (!mounted || _uid != uid) return;
          setState(() {
            _loading = false;
            _loadError = true;
          });
        });
  }

  static String _string(Object? value) => value is String ? value.trim() : '';

  static String _firstText(Iterable<String> values) {
    for (final value in values) {
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String get _normalizedPhone {
    final value = _phone.text.trim();
    return value.isEmpty ? '' : Validators.normalizePhone(value);
  }

  String get _originalNormalizedPhone =>
      _originalPhone.isEmpty ? '' : Validators.normalizePhone(_originalPhone);

  bool get _dirty =>
      _loaded &&
      (_name.text.trim() != _originalName ||
          _normalizedPhone != _originalNormalizedPhone ||
          _sms != _originalSms ||
          _paperless != _originalPaperless);

  Future<bool> _askDiscard({required bool leave}) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(leave ? 'Discard unsaved changes?' : 'Discard changes?'),
        content: Text(
          leave
              ? 'Your profile changes have not been saved.'
              : 'Your unsaved profile changes will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(leave ? 'Keep Editing' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return answer == true;
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('profile');
    }
  }

  Future<void> _back() async {
    if (_saving) return;
    if (_dirty && !await _askDiscard(leave: true)) return;
    if (mounted) _leave();
  }

  Future<void> _discard() async {
    if (!_dirty || _saving || !await _askDiscard(leave: false)) return;
    if (!mounted) return;
    setState(() {
      _name.text = _originalName;
      _phone.text = _originalPhone;
      _sms = _originalSms;
      _paperless = _originalPaperless;
    });
    _formKey.currentState?.reset();
  }

  Future<Uint8List?> _pickPhoto(ImageSource source) async {
    final picker = widget.photoPicker;
    if (picker != null) return picker(source);
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 320,
      maxHeight: 320,
      imageQuality: 72,
      preferredCameraDevice: CameraDevice.front,
    );
    return file?.readAsBytes();
  }

  Future<void> _writePhoto(String value) async {
    final uid = _uid;
    if (uid == null) return;
    final changes = {'photoUrl': value};
    if (widget.profileWriter != null) {
      await widget.profileWriter!(uid, changes);
    } else {
      await FirestoreService().database
          .collection('users')
          .doc(uid)
          .update(changes);
    }
  }

  Future<void> _choosePhoto() async {
    if (!_loaded || _saving || _savingPhoto) return;
    final hasCustomPhoto = ProfilePhotoData.isData(_photoUrl);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            if (hasCustomPhoto)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'remove') return _removePhoto();
    final Uint8List? bytes;
    try {
      bytes = await _pickPhoto(
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
    } on PlatformException {
      _snack(
        choice == 'camera'
            ? 'Camera access is needed to take a photo. Allow it in Settings.'
            : 'Photo access is needed to choose a picture. Allow it in Settings.',
      );
      return;
    }
    if (!mounted || bytes == null) return;
    final encoded = ProfilePhotoData.encode(bytes);
    if (encoded == null) {
      _snack('Choose a JPEG or PNG photo.');
      return;
    }
    if (encoded.length > ProfilePhotoData.maxEncodedLength) {
      _snack('That photo is too large. Try another one.');
      return;
    }
    await _savePhoto(encoded, 'Profile photo updated.');
  }

  Future<void> _removePhoto() => _savePhoto('', 'Profile photo removed.');

  Future<void> _savePhoto(String value, String success) async {
    final previous = _photoUrl;
    setState(() {
      _savingPhoto = true;
      _photoUrl = value;
    });
    try {
      await _writePhoto(value);
      _snack(success);
    } catch (_) {
      if (mounted) setState(() => _photoUrl = previous);
      _snack('Your photo could not be saved. Please try again.');
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!_loaded || _saving || !_dirty) return;
    if (_formKey.currentState?.validate() != true) return;
    final uid = _uid;
    if (uid == null || _identity(context)?.uid != uid) return;
    final changes = <String, Object?>{};
    if (_name.text.trim() != _originalName) {
      changes['fullName'] = _name.text.trim();
    }
    if (_normalizedPhone != _originalNormalizedPhone) {
      changes['phone'] = _normalizedPhone.isEmpty ? null : _normalizedPhone;
    }
    if (_sms != _originalSms) {
      changes['preferences.readyForPickupSms'] = _sms;
    }
    if (_paperless != _originalPaperless) {
      changes['preferences.paperlessInvoices'] = _paperless;
    }
    if (changes.isEmpty) return;
    setState(() => _saving = true);
    try {
      if (Firebase.apps.isNotEmpty &&
          FirebaseAuth.instance.currentUser?.uid != uid) {
        throw StateError('The signed-in account changed.');
      }
      if (widget.profileWriter != null) {
        await widget.profileWriter!(uid, changes);
      } else {
        await FirestoreService().database
            .collection('users')
            .doc(uid)
            .update(changes);
      }
      if (!mounted) return;
      try {
        await context.read<AuthProvider>().refreshProfile();
      } catch (_) {
        // ProfileScreen also reloads the saved document when it opens.
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      context.goNamed('profile');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save changes. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isShopPartner) {
      return const MerchantEditProfileView();
    }
    final identity = _identity(context);
    if (identity != null) _startLoading(identity.uid);
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          centerTitle: true,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _saving ? null : _back,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Edit Profile'),
        ),
        body: SafeArea(
          top: false,
          child: identity == null
              ? const Center(child: Text('Sign in to edit your profile.'))
              : _loading
              ? const Center(child: CircularProgressIndicator())
              : _missing || _loadError
              ? _unavailable()
              : !_loaded
              ? const Center(child: CircularProgressIndicator())
              : _form(identity),
        ),
      ),
    );
  }

  Widget _unavailable() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_off_outlined,
            color: AppColors.secondaryText,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            _missing
                ? 'Your customer profile is unavailable.'
                : 'Profile details could not be loaded.',
          ),
          const SizedBox(height: 12),
          if (_loadError)
            TextButton(
              onPressed: () {
                setState(() => _uid = null);
              },
              child: const Text('Retry'),
            ),
          TextButton(onPressed: _back, child: const Text('Back to Profile')),
        ],
      ),
    ),
  );

  Widget _form(EditProfileIdentity identity) {
    final name = _firstText([
      _originalName,
      _string(identity.displayName),
      _string(identity.email),
    ]);
    final displayName = name.isEmpty ? 'PikZen customer' : name;
    final imageUrl = _firstText([_photoUrl, _string(identity.photoUrl)]);
    final initials = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        28 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 51,
                        backgroundColor: AppColors.softGreen,
                        child: ClipOval(
                          child: SizedBox.expand(
                            child: _savingPhoto
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : ProfilePhoto(
                                    source: imageUrl,
                                    fallback: Center(
                                      child: Text(
                                        initials,
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 30,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -10,
                        bottom: -5,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.surface,
                          child: IconButton(
                            tooltip: 'Change profile photo',
                            onPressed: _saving || _savingPhoto
                                ? null
                                : _choosePhoto,
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _saving || _savingPhoto ? null : _choosePhoto,
                    child: Text(
                      ProfilePhotoData.isData(_photoUrl)
                          ? 'Change Photo'
                          : 'Add Photo',
                    ),
                  ),
                ),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (_createdAt != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Member since ${_createdAt!.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 22),
                _fieldCard(
                  label: 'Full Name',
                  trailing: const _Tag('Required'),
                  child: TextFormField(
                    key: const ValueKey('fullName'),
                    controller: _name,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(Icons.person_outline),
                    validator: Validators.name,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 12),
                _fieldCard(
                  label: 'Email Address',
                  trailing: identity.emailVerified
                      ? const _Tag('Verified', green: true)
                      : null,
                  child: TextFormField(
                    key: const ValueKey('email'),
                    initialValue: _firstText([_string(identity.email)]),
                    readOnly: true,
                    enableInteractiveSelection: true,
                    decoration: _inputDecoration(
                      Icons.mail_outline,
                      suffix: const Icon(Icons.lock_outline, size: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _fieldCard(
                  label: 'Phone Number',
                  child: TextFormField(
                    key: const ValueKey('phone'),
                    controller: _phone,
                    enabled: !_saving,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    decoration: _inputDecoration(Icons.phone_outlined),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? null
                        : Validators.phone(value),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Preferred Pickup Hub / Address',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<OrderModel>>(
                  stream: _orders,
                  builder: (context, snapshot) {
                    final orders = [...?snapshot.data]
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    OrderModel? latest;
                    for (final order in orders) {
                      if (_string(order.shopName).isNotEmpty) {
                        latest = order;
                        break;
                      }
                    }
                    return _hubCard(latest?.shopName);
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  'Pickup & Receipt Preferences',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _preferenceCard(
                  icon: Icons.sms_outlined,
                  title: 'Order Ready for Pickup SMS',
                  subtitle: 'Save your alert preference. SMS delivery is not available yet.',
                  value: _sms,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _sms = value),
                ),
                const SizedBox(height: 10),
                _preferenceCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Paperless Digital Invoices',
                  subtitle: 'Save your preference for digital receipts.',
                  value: _paperless,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _paperless = value),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving || !_dirty ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(_saving ? 'Saving...' : 'Save Changes'),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: _saving || !_dirty ? null : _discard,
                    child: const Text('Discard Unsaved Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldCard({
    required String label,
    required Widget child,
    Widget? trailing,
  }) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );

  InputDecoration _inputDecoration(IconData icon, {Widget? suffix}) =>
      InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.primary),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );

  Widget _hubCard(String? name) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        const Icon(Icons.location_on_outlined, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name ?? 'No preferred pickup hub saved',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                name == null
                    ? 'A hub appears after you place an order.'
                    : 'From a recent order • No saved default hub',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        TextButton(onPressed: null, child: const Text('Change')),
      ],
    ),
  );

  Widget _preferenceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    ),
    child: SwitchListTile(
      secondary: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      value: value,
      activeThumbColor: AppColors.primary,
      onChanged: onChanged,
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.green = false});
  final String label;
  final bool green;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: green ? AppColors.softGreen : AppColors.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: green ? AppColors.primary : AppColors.secondaryText,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

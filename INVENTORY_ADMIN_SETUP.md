# Member 1 discovery and Admin integration

## Shared product contract
There was no implemented shop inventory repository or Firestore product schema:
the shop provider and inventory screens are placeholders. The existing
FirestoreService and ProductProvider now use a single products/{productId} stream.

Canonical fields: name (string), category (string), priceMinor (integer LKR cents),
currencyCode (LKR), stockQuantity (nonnegative integer), lowStockThreshold
(nonnegative integer, defaults to 5), imageUrl (local assets/... or HTTPS), shopId
(the owning approved shop user's Authentication UID), unit, description.
Document ID is the product ID. Optional display fields: shopName, brand, origin,
storage, packaging, dietary, harvestLabel, readiness, rating, isOrganic,
originalPriceMinor. Missing optional values are omitted from UI or safely defaulted.

The model can read legacy price in rupees if priceMinor is absent, and imagePath
if imageUrl is absent. Future inventory writers should use the canonical fields.
Dairy/Veggies/Pantry category names normalize to Dairy & Eggs/Vegetables/Pantry Staples.
No competing inventory collection, stock-status field, or customer price list was added.

Stock status derives solely from stockQuantity and lowStockThreshold. Cart provider
reconciles prices and clamps/removes quantities when snapshots arrive. Checkout must
still verify stock transactionally on the backend; a client cart is not a reservation.
Other members' screen files were not changed. Their future Inventory UI should write
this same products collection, with shopId equal to the signed-in approved shop UID.

The original four demo products are the only fallback while no live products have
loaded; this is labelled Demo catalog. A live catalog replaces the fallback entirely.
Once live data has loaded, an empty snapshot stays empty (deleted products do not
reappear as demos). Stream errors are shown with Retry. Favourites store only product
IDs in the existing session-scoped provider and always resolve latest catalog records.

## Member 1 screens
Categories display eight local-asset aisles with computed item counts. Tapping an aisle
or submitting category search opens the same Search Results screen using category/q
parameters. Search supports case-insensitive matching, category, organic, available-stock
filters and price/name sorting. Search retains the existing five-item customer bottom bar.
Details resolve by product ID, show available metadata, and add to the existing Cart.
The share control copies product details and its app route to the clipboard.
Favourites use the same product/cart state; Add All adds one unit per available saved
product and respects current stock limits. Home retains its layout with shared data binding.

## Admin
Common login now routes admins to /admin/users (admin-users). The router denies
customer/shop access. The screen streams users from the existing FirestoreService,
searches names/emails and filters All/Customers/Shop Owners/Pending Shops.
Approve/Reject use the existing reviewShop transaction, changing only approvalStatus
after confirmation. No role editing or suspension mutation is available.
Active/Suspended statistics count explicit accountStatus fields if present; otherwise
they say Not tracked. Approval status is displayed separately. Logout uses AuthProvider.

## Rules and deployment
Firestore rules deployment required: YES. Nothing was deployed to production.
Merge/deploy the users and products sections without removing other members' rules.
Product reads require authentication. Product writes require an approved shop owner,
a matching immutable shopId, and valid nonnegative integer price/quantity fields.
Client product deletion is denied. Admin approval rules remain pending-to-approved/rejected
only, with no client role promotion, self-approval, or public admin creation.

No new composite indexes are required for these all-record streams and client filters.
The existing pendingShops equality query may use Firestore's standard index merging.
For existing shop profiles, missing/null approvalStatus requires explicit migration to
pending (approved only after trusted review). No live user records were inspected or changed.
Existing product documents, if provisioned separately, should adopt the canonical fields
above before shop-side writes. No automatic migration or product seeding was run.

## Validation
Run flutter analyze and flutter test --no-pub.
The privileged-user creation script is reused unchanged.
Local rule test command and Java setup are in scripts/README.md; firebase.emulator.json
targets only the demo-pikzen-approval project on localhost:8087.


## Final continuation verification (2026-09-26)
- flutter analyze: No issues found.
- flutter test --no-pub: all 42 tests passed.
- node --test scripts/create_privileged_user.test.js: all 10 tests passed.
- Firestore rule tests: not run. The emulator JAR is absent; prior official
  downloads failed to complete/checksum correctly. Rule test source remains
  available for execution once the emulator can be installed.
- Firestore rules deployment required: YES. No production deployment was performed.
- This continuation preserved the already completed implementation; only these
  setup notes were changed after final verification.
- No Git commit, push, branch creation, merge, or other Git write operation was run.

## Files in the completed Member 1/Admin change
- lib/app.dart
- lib/core/router/app_router.dart
- lib/core/services/auth_service.dart
- lib/core/services/firestore_service.dart
- lib/models/product_model.dart
- lib/models/user_model.dart
- lib/features/auth/providers/auth_provider.dart
- lib/features/cart_checkout/providers/cart_provider.dart (state only; Cart UI untouched)
- lib/features/product_discovery/providers/product_provider.dart
- lib/features/product_discovery/screens/categories_screen.dart
- lib/features/product_discovery/screens/search_screen.dart
- lib/features/product_discovery/screens/product_details_screen.dart
- lib/features/product_discovery/screens/favourites_screen.dart
- lib/features/product_discovery/screens/customer_home_screen.dart (data/status and label sizing only)
- lib/features/product_discovery/widgets/product_card.dart
- lib/features/product_discovery/widgets/discovery_ui.dart
- lib/features/admin/providers/admin_users_provider.dart
- lib/features/admin/screens/admin_users_screen.dart
- firestore.rules
- scripts/shop_approval_rules.test.js
- test/auth_forms_test.dart
- test/discovery_admin_test.dart
- FIREBASE_AUTH_SETUP.md
- INVENTORY_ADMIN_SETUP.md

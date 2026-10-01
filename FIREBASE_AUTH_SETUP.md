# PikZen authentication setup

No Firebase project configuration or live rules were deployed by this implementation.

- Enable Email/Password and Google in Firebase Console > Authentication > Sign-in method.
- Add the Android debug/release SHA-1 and SHA-256 fingerprints in Project settings. Download the updated google-services.json into its existing location. The checked-in Android config currently contains no OAuth clients; Google sign-in needs the generated web OAuth client (client_type 3).
- Web uses FirebaseAuth.signInWithPopup. Register a Firebase web app, configure Firebase.initializeApp with the Console-provided web options, and authorize the deployed host (and localhost for development). The current main.dart only has native default initialization; it was left unchanged.
- Merge the users/{uid} section of firestore.rules into the existing deployed rules, preserving other members' rules. Public clients may create role=customer (without approvalStatus) or role=shop with approvalStatus=pending; they must never edit role or approvalStatus. Deploy the updated users rules before enabling shop signup. Provision Admin accounts through the privileged-user script; normal Shop Owners use Sign Up.
- Profiles use users/{uid}: uid, fullName, email, phone, role, createdAt (server timestamp). Passwords are never stored in Firestore or preferences.
- Customer routes to customer-home; only shop + approved routes to shop-dashboard. Pending, rejected, legacy missing-status, and invalid-status shops cannot enter shop routes. Admins now route to the protected /admin/users User Management screen.
- Remember Me stores a boolean preference only. Web chooses LOCAL or SESSION persistence; native Firebase keeps its standard persisted-session behavior.
- The phone field is contact information, not a linked phone-auth credential. Email reset is the only recovery method for these accounts. SMS is deliberately unavailable. A future phone-auth flow needs provider activation, app verification/SHA configuration, and verified phone linking before offering phone recovery; enabling Phone in the Console alone does not add SMS password reset to email/password accounts.
- The product provider contains a single local four-product launch catalog using supplied assets and reference prices. Inventory/promotions are not live shop data. Cart and favourites are shared in-memory session state and clear when the authenticated user changes. No fake cart counters or separate favourites lists are used by screens.
- The promotional banner is a UI preview; its button does not claim a discount was applied. Terms/Privacy content must be supplied before public release.

Official setup references:
https://firebase.google.com/docs/auth/flutter/federated-auth
https://firebase.google.com/docs/auth/flutter/password-auth
https://pub.dev/packages/google_sign_in_android


## Shop approval integration
- Sign Up defaults to Customer and also offers Shop Owner; Admin is never public.
- Public shops get approvalStatus=pending. Google first-time accounts remain customers.
- FirestoreService.pendingShops() lists shop/pending profiles for an authenticated Admin.
- FirestoreService.reviewShop(uid, approvalStatus: 'approved' or 'rejected') applies
  one pending-to-decision transition transactionally. Rules enforce the Admin role,
  protect all other fields, and disallow public role changes/self-approval.
- Admin/User Management is connected: it streams the user directory, filters pending shops, and calls reviewShop after confirmation. General role editing and suspension mutations are not exposed.
- users.createdAt is represented as nullable DateTime in UserModel; existing customers
  without approvalStatus continue working.
- Migration candidates: existing users documents with role=shop and missing/null
  approvalStatus. Set pending unless explicitly reviewed as trusted/demo (then approved).
  Unknown status values also need manual correction. Legacy records are not deleted.
  Live Firestore was not inspected, so specific affected UIDs are not known.
- No migration or rules deployment is performed automatically.
- Future shop-owned data collections must independently enforce approved-shop access
  in their own rules; route guards are UI protection, not a backend authorization boundary.
- Rules reference: https://firebase.google.com/docs/rules/basics

## Historical verification for the earlier approval update
- Flutter analysis: no issues; 33 Flutter tests passed.
- Privileged-user utility: 10 offline tests passed.
- Firestore rule tests are provided but were not executed: the official emulator
  download did not complete. Run the documented local emulator command before
  deploying the changed rules. No live rules or account records were modified.

Files changed in this update:
- lib/models/user_model.dart
- lib/core/services/auth_service.dart
- lib/core/services/firestore_service.dart
- lib/features/auth/providers/auth_provider.dart
- lib/features/auth/screens/signup_screen.dart
- lib/core/router/app_router.dart
- firestore.rules
- scripts/create_privileged_user.js
- scripts/create_privileged_user.test.js
- scripts/README.md
- test/auth_test_support.dart
- test/auth_forms_test.dart
- FIREBASE_AUTH_SETUP.md

Files added:
- test/shop_approval_test.dart
- scripts/shop_approval_rules.test.js
- firebase.emulator.json (local testing only)

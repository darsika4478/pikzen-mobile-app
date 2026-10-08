# One-time privileged account setup

Local developer utility primarily for Admin creation, not part of the Flutter app. It assigns shop/admin roles to
new or existing accounts. Run only for accounts you intend to grant those privileges.
Normal Shop Owners should now use PikZen Sign Up, choose Shop Owner, and wait for Admin approval. Use this script for Admin accounts and optionally trusted/demo shops.

## Run (PowerShell, from the repository root)

1. Install Node.js 22+ and run `npm ci` (firebase-admin is the only added dependency).
2. Enable Firebase Authentication and create the Firestore database in your existing
   project. Use an operator identity with Authentication user-management and
   Firestore read/write permissions. Admin SDK access uses IAM, not client rules.
3. Configure Application Default Credentials. For a service-account key, keep it
   **outside this repository**, restrict local file access, and never commit or share it:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\secure\pikzen\service-account.local.json"
$env:GOOGLE_CLOUD_PROJECT = "your-firebase-project-id"
node scripts/create_privileged_user.js
```

Use a key issued for the intended project. An already configured ADC identity can
be used instead of a key file. See [Firebase Admin setup](https://firebase.google.com/docs/admin/setup).

Choose role first. For shop, choose pending (default) or explicitly approved for a trusted/demo account. Then enter email, full name, optional phone, and password at the hidden prompt.
Never select approved for an unreviewed account. Only `shop` and `admin` are accepted; password minimum is eight characters.
Example inputs (supply your own password at the prompt):
- Shop Owner: `shop@example.com`, `Example Shop Owner`, `+94770000000`, `shop`.
- Admin: `admin@example.com`, `Example Administrator`, blank phone, `admin`.

Optional environment inputs: `PIKZEN_EMAIL`, `PIKZEN_FULL_NAME`, `PIKZEN_PHONE`,
`PIKZEN_ROLE`, `PIKZEN_APPROVAL_STATUS`, `PIKZEN_PASSWORD`. Prefer the hidden prompt for passwords; never
put passwords in command arguments, shell history, tracked files, or logs. For
unattended use, inject the password through a trusted secret manager and clear it
from the parent environment afterward. The script does not load .env files.

Example: set `$env:PIKZEN_ROLE = "shop"` (or `"admin"`) and run the same command.
Clear any PIKZEN_* environment values before provisioning a different account.

## Behavior and recovery

- Uses Authentication UID for `users/{uid}`: uid, fullName, email, phone, role,
  createdAt. Phone is stored as a string; new profiles default to an empty string.
- Reuses existing Authentication accounts without changing their password,
  display name, verification state, or disabled state. Supplied password is still
  validated but ignored for an existing account.
- Deliberately updates the supplied profile name/role and supplied phone; blank
  phone preserves an existing value. Unrelated fields and existing createdAt
  survive the transactional merge; a missing timestamp gets serverTimestamp.
- Auth and Firestore writes are not atomic together. If the profile write fails,
  fix configuration and rerun. No accounts are deleted or passwords reset.
- Exit code 0 means success; 1 means validation/configuration/write failure.
  No real Firebase accounts are created by the offline tests.
- Shop/Admin dashboard routing is outside this utility's scope.

The ignore rules cover node_modules, .env files, .credentials directories,
service-account.local.json, common service-account filenames, and private-key files.
Ignoring a file does not untrack a previously committed secret; rotate any exposed key.

Run offline checks: `node --test scripts/create_privileged_user.test.js`.
SDK behavior reference: [Manage users](https://firebase.google.com/docs/auth/admin/manage-users).


Shop profiles additionally store approvalStatus. Default is pending, including reruns; set PIKZEN_APPROVAL_STATUS=approved explicitly only for trusted/demo shops. Admin creation does not add approvalStatus. No existing shop is silently approved or migrated.

## Local security-rule tests
Use Java 21+ (the Android Studio bundled JBR works) and Node 22+:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
npx --yes firebase-tools@15.31.0 emulators:exec --only firestore --project demo-pikzen-approval --config firebase.emulator.json "node --test scripts/shop_approval_rules.test.js"
```

Run from the repository root. The dedicated config is for local testing only;
the tests use a fixed demo project and the local emulator, never production credentials.
They verify public creation restrictions, role/approval protection, admin decisions,
legacy shop handling, and admin-only queries. Do not deploy this emulator config.

## Demo data seed (campus demo)

`scripts/seed_demo_data.js` creates fictional accounts, 19 products for an approved
demo shop, and three sample orders (placed / preparing / ready) with simulated
payment receipts. It only writes `demo-*` documents and the accounts below, and
reruns reset them. Existing accounts keep their passwords.

| Role | Email |
| --- | --- |
| Customer | `demo.customer@pikzen.test` |
| Approved shop | `demo.shop@pikzen.test` (PikZen Demo Mart) |
| Pending shop | `demo.pending@pikzen.test` (for the admin approval demo) |
| Admin | `demo.admin@pikzen.test` |

```powershell
# Real project (same credential setup as above); you are prompted for the password.
$env:GOOGLE_CLOUD_PROJECT = "pikzen-mobile-app"
node scripts/seed_demo_data.js

# Or local emulators (no credentials needed); set both hosts.
$env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:8087"
$env:FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099"
node scripts/seed_demo_data.js
```

## Demo payments

No payment provider is contacted and nothing is charged. Each order gets a
receipt at `payments/{orderId}` (reference `DEMO-XXXXXXXX`); card receipts keep
only the last four digits. Cash orders stay `pending` until the shop marks the
order collected, which sets them to `paid`.

| Dummy card | Result |
| --- | --- |
| `4242 4242 4242 4242` (or any other 16 digits) | Approved |
| `4000 0000 0000 0002` | Declined |
| `4000 0000 0000 9995` | Insufficient funds |

Any future `MM/YY` expiry and any 3-digit CVV work; past expiry dates are rejected.

## Backend rule tests

`scripts/backend_rules.test.js` covers payment receipts, order chat, favourites
and order-event notifications. Run it like the other rule tests:

```powershell
npx --yes firebase-tools@15.31.0 emulators:exec --only firestore --project demo-pikzen-backend --config firebase.emulator.json "node --test scripts/backend_rules.test.js scripts/order_rules.test.js scripts/shop_approval_rules.test.js"
```

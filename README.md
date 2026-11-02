# Bookmarkd

A book tracker with a light social layer — Letterboxd for books.
Flutter 3 (iOS + Android), Supabase backend, Google Books catalog with an Open Library fallback.

Track what you want to read, are reading and have finished; log progress; rate (half stars) and review;
follow readers and see what they're reading.

## Set up

The app always talks to Supabase; a build without `SUPABASE_URL` and the key stops at startup
with an error saying so.

1. Create a Supabase project.
2. Apply the schema — either paste
   `supabase/migrations/20261102000000_initial_schema.sql` into the SQL editor and run it, or with the CLI:
   ```bash
   supabase link --project-ref <your-project-ref>
   ```
   ```bash
   supabase db push
   ```
   This creates the tables, RLS policies, indexes, activity triggers, RPC functions and a public
   `avatars` storage bucket.
   Then deploy the Edge Function that saves books (it fetches metadata server-side, so clients can't
   write fake titles or covers into the shared catalog):
   ```bash
   supabase functions deploy save-book
   ```
   ```bash
   supabase secrets set GOOGLE_BOOKS_API_KEY=<your key>
   ```
   The key is strongly recommended here: all saves come from Supabase's servers, and keyless Google
   requests are rate-limited per IP.
3. In **Authentication → URL configuration → Redirect URLs**, add
   `com.bookmarkd.bookmarkd://reset-password`. The password-reset email links back into the app
   (registered in `AndroidManifest.xml` and `Info.plist`), which then asks for a new password.
4. Create a `.env` file in the project root (it is gitignored):
   ```
   SUPABASE_URL=https://<project-ref>.supabase.co
   SUPABASE_PUBLISHABLE_KEY=<publishable or anon key>
   GOOGLE_BOOKS_API_KEY=
   PASSWORD_RESET_REDIRECT=
   ```
   Only the publishable/anon key goes here — it is public by design and data is protected by RLS.
   **Never put the service-role key in the app.** `PASSWORD_RESET_REDIRECT` can stay empty (defaults to
   `com.bookmarkd.bookmarkd://reset-password`). `GOOGLE_BOOKS_API_KEY` is optional but recommended:
   without it Google rate-limits quickly (the app then falls back to Open Library).
5. Run:
   ```bash
   flutter run --dart-define-from-file=.env
   ```

## Release builds

Every build needs the same `--dart-define-from-file=.env`.

**Android.** Create an upload key once (keep the file and passwords safe — losing them means you can
no longer update the app on Google Play):
```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Then create `android/key.properties` (gitignored):
```
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=upload-keystore.jks
```
`storeFile` is relative to `android/app`. Without this file, release builds are signed with the debug
key and Google Play will reject them.
```bash
flutter build appbundle --dart-define-from-file=.env
```

**iOS.** Open `ios/Runner.xcworkspace` in Xcode, set your Team under Signing & Capabilities, then:
```bash
flutter build ipa --dart-define-from-file=.env
```

Bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2`) before every store upload.

## Project layout

```
lib/
  app/            app widget, DI (get_it), router (go_router), theme tokens
  core/           repository interfaces, errors, network, services, shared widgets
  features/
    auth/ onboarding/ home/ books/ search/ library/
    reading/ reviews/ social/ profile/ statistics/
      domain/       pure models and rules
      data/         Supabase / HTTP implementations
      presentation/ cubits, pages, widgets
supabase/migrations/   SQL schema, RLS, triggers, RPCs
supabase/functions/    save-book Edge Function
docs/ARCHITECTURE.md   data model, glossary, routes, APIs, design system
```

State: `flutter_bloc` cubits. The signed-in session and the reader's library are app-wide cubits;
everything else is scoped to its screen. Library writes are optimistic and roll back on failure.

## Key design decisions

- **Work vs edition.** `books` is the literary work, `book_editions` a specific printing (ISBNs, pages,
  cover). A reader has at most one library entry per work, pointing at the edition they read.
- **Only added books are stored.** Search hits the external catalog; metadata is saved (deduplicated by
  Google id → Open Library id → ISBN-13 → ISBN-10) only when someone adds the book, via the
  `save-book` Edge Function, which fetches the metadata itself and calls `upsert_catalog_book`
  (service role only). Clients send ids, never metadata, and cannot write book tables.
- **The database owns invariants.** Activity feed events are written by triggers; progress updates go
  through `log_reading_progress`, which validates the page against the edition and records a session
  atomically. Follows can't target yourself; likes and follows are unique.
- **Privacy.** A private profile's library, reviews and activity are visible only to its owner.
  Emails stay in `auth.users`.
- **No invented data.** Popular / trending / community ratings come from real library data only.
  Recommendations are a stated heuristic: "popular in your most-read genre".
- **Sessions** are stored in the Keychain / Keystore (`flutter_secure_storage`).

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full schema and routes.

## Database tests

`supabase/tests/database/privacy.test.sql` (pgTAP) checks that a private reader's library, reviews and
activity are hidden from others and that clients cannot write catalog books. Run against a local stack:

```bash
supabase test db
```

## Status and known gaps

- The Supabase setup (migrations, Edge Function, repositories) has **not been run against a live
  project** yet; expect to fix small issues on first deploy.
- Apple / Google sign-in are not implemented; auth goes through `AuthRepository`, so they can be added there.
- No follow requests: "private" means visible to you only.
- Google Books cover images may not load in a Flutter **web** build (web is not a target platform).

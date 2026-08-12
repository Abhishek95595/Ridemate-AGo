# AGo — Play Store Release Checklist

This tracks the pre-submission review done before AGo's first Play Store
release: what was found, what's been fixed, and what's still open. Update
the checkboxes as items get done — don't delete this file once published,
it's the record of what shipped in the first release.

## Code & config — done

- [x] **Package renamed** `com.example.ride_mate` → `com.anvyaai.ago`
      (Gradle `applicationId`/`namespace`, Kotlin source path, native
      fallback namespace in `android/build.gradle.kts`).
- [ ] **Restore release signing on this machine** — `android/key.properties`
      and `android/keystore/ago-release-upload.jks` are currently absent.
      Release tasks now fail explicitly instead of creating a debug-signed
      bundle that could be uploaded accidentally.
- [ ] **Confirm the upload keystore backup and password-manager entry** — the `.jks` file, `key.properties`,
      and the store/key password are saved somewhere safe outside this
      repo (password manager / secure storage), not committed to version
      control.
- [x] **Removed unused dangerous permissions** — `SEND_SMS`, `CALL_PHONE`,
      `READ/WRITE_EXTERNAL_STORAGE`, `CAMERA`, and `ACCESS_WIFI_STATE` dropped from `AndroidManifest.xml`;
      dead native `SmsManager` MethodChannel removed from `MainActivity.kt`
      (SOS actually uses `url_launcher`'s `sms:`/`tel:` intents, which need
      no permission).
- [x] **R8/ProGuard minification enabled** for release builds, with keep
      rules for Firebase/Play Services/flutter_local_notifications/geolocator
      (`android/app/proguard-rules.pro`). Build-tested successfully with R8 and resource shrinking on 11 Aug 2026;
      the test artifact was debug-signed because the upload key is absent.
- [x] **Adaptive icon background color** fixed to match `pubspec.yaml`
      (`#0B1F3A`) — was hardcoded to `#000000` in the generated resource.
- [x] **Unused `flutter_secure_storage` dependency** removed.
- [x] **Google API keys pulled out of app source** — Android reads the Maps
      SDK key from `android/local.properties`; Dart reads Maps, Places, and
      Routes keys from `String.fromEnvironment` in
      `lib/config/api_config.dart`. Use the gitignored `dart_defines.json`
      with `--dart-define-from-file`.
- [x] **In-app account deletion** added (Profile → Delete Account) —
      deletes the profile doc, profile/licence photos, and the Firebase
      Auth account; handles the `requires-recent-login` re-auth case.
      Ride/booking records are intentionally retained (disclosed in the
      privacy policy) for the other party's history and dispute resolution.
- [x] **Firestore & Storage security rules drafted** (`firestore.rules`,
      `storage.rules`), reverse-engineered from the app's actual
      reads/writes, wired into `firebase.json`. **Not yet deployed or
      tested against the app** — see Outstanding below.
- [x] **Privacy Policy & Terms of Service drafted** (`legal/privacy-policy.html`,
      `legal/terms-of-service.html`), linked from the Signup and Profile
      screens via `lib/core/constant/app_links.dart`. The production URLs are hosted and configured.
- [x] **Branding cleanup** — README, `pubspec.yaml` description consistent
      with the app's actual name/purpose.

## Firebase / Google Cloud — done

- [x] New Android app registered in Firebase project `ridemate-43114` for
      `com.anvyaai.ago`.
- [x] Both SHA-1 fingerprints (release + local debug keystore) added to
      that Firebase Android app — Google Sign-In confirmed working
      (`client_type: 1` OAuth entries present in `google-services.json`).
- [x] `android/app/google-services.json` and `lib/firebase_options.dart`
      updated to match the new Android app registration.
- [x] Firebase project **Environment type** set to Production.
- [x] Google Maps API key restricted (Application restriction: Android
      apps, both SHA-1s + `com.anvyaai.ago`; API restriction: Maps SDK for
      Android, Places API, Directions API, Geocoding API).
- [x] Firebase Hosting configured and deployed for the privacy policy and ToS.

## Verification completed on 11 Aug 2026

- [x] Full Dart analysis: zero errors and zero warnings (informational lints remain).
- [x] Debug APK compiled after cleanup and manifest hardening.
- [x] Minified/resource-shrunk release AAB compiled before the signing guard was
      enabled; signature inspection confirmed it used the Android debug key.
- [x] Release builds now stop when the upload key is absent.
- [ ] Automated tests: no `test/` or `integration_test/` suite exists yet.
- [ ] Android walkthrough: blocked because no Android device or AVD is connected.

## Outstanding — do these before submitting

### Local environment
- [x] `android/local.properties` is present with local Flutter/Android SDK
      paths and a Maps SDK key.
- [x] First successful `flutter run` on a physical device — app builds and
      launches.

### Verification
- [ ] Full manual walkthrough: signup (email + Google Sign-In), publish a
      ride, find/book a ride, chat, SOS, rate a user, edit profile,
      **delete account** (new feature, test both the normal path and the
      "please log in again" path).
- [ ] **Phone number (OTP) login investigation deferred** — hit a Firebase
      `invalid app identifier` error verifying a real phone number on one
      device; unclear yet whether it's Play Integrity API not being
      enabled for `ridemate-43114`, or something device-specific. Not
      blocking other work, but needs resolving before relying on phone
      login for real users — email/password and Google Sign-In are
      unaffected. Workaround in the meantime: add test numbers in Firebase
      Console → Authentication → Sign-in method → Phone.
- [ ] Deploy `firestore.rules`/`storage.rules` to a **staging project or
      the Firebase emulator first**, not directly to production — the
      rules were written from reading the code, not from running it, and
      a wrong field name would silently break a flow rather than error
      loudly. Only point them at production Firestore after the manual
      walkthrough above passes against them.
- [ ] Expect to need to create Firestore composite indexes the first time
      the geo/ride queries run (Firestore will show a console link in the
      error when this happens — not a bug, just needs doing once).

### Legal docs
- [x] Deployed via `firebase deploy --only hosting`, and mapped to a custom
      domain via Firebase Hosting + DNS (CNAME at Vercel) instead of the
      default `.web.app` domain. Live at:
      `https://ago.anvyaai.com/privacy-policy` and
      `https://ago.anvyaai.com/terms-of-service` (both verified over HTTPS).
- [x] `privacyPolicyUrl` and `termsOfServiceUrl` in
      `lib/core/constant/app_links.dart` updated to match.
- [ ] Use the same privacy policy URL in Play Console's "Privacy policy"
      field and Data Safety section.

### Play Console (all external to this repo)
- [ ] Developer account registered ($25 one-time fee, if not already done).
- [ ] **If this is a new/personal Play Console account**: start the closed
      testing track now (12+ testers opted in for 14 continuous days) —
      required before production access is granted, and the biggest
      timeline item left.
- [ ] Store listing: title, short/full description, app icon (512×512),
      feature graphic (1024×500), 2+ phone screenshots, category, contact
      email.
- [ ] Content rating questionnaire (IARC) — answer honestly re: user chat,
      location sharing, user-generated content.
- [ ] Data Safety form — must match the privacy policy exactly (location,
      personal info, financial info for the UPI ID, user content for chat).
- [ ] Account deletion declaration (separate checkbox from Data Safety) —
      point it at the in-app flow / privacy policy URL.
- [ ] Reviewer test account — almost everything in the app requires login,
      so provide test credentials in App Content, or review can't proceed.
- [ ] Target country/region — likely restrict to India, since UPI payment
      only works there.
- [ ] Opt in to Play App Signing on first upload.

## Known residual risk

The original Maps API key value was committed in plaintext in the initial
commit (manifest + two Dart files) before this review. It's since been
restricted (see above) and removed from all current source, but it still
exists in **git history**. If this repo's history is or becomes public,
consider that key permanently exposed regardless of the restriction (the
restriction limits what it can be *used* for, not whether it's visible).
Rotating it entirely (new key, delete the old one) removes the risk
completely if that matters for your repo's visibility.

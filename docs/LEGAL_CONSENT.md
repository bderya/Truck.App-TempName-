# Legal Consent & Compliance Flow

## Overview

The app implements mandatory legal consent (KVKK, EULA) during registration and stores consent version and date in the database for compliance (App Store, KVKK).

## Data Storage

- **Folder**: `/assets/legal/`
- **Files** (replace placeholder content with your final texts):
  - `kvkk.html` — Gizlilik Politikası / KVKK Aydınlatma Metni
  - `eula.html` — Son Kullanıcı Lisans Sözleşmesi (EULA)
  - `sales_agreement.html` — Mesafeli Satış ve Hizmet Sözleşmesi

Declare in `pubspec.yaml` under `flutter.assets` (already added: `- assets/legal/`).

## Registration UI

### Client (Lazy registration)

- **Screen**: `LazyAuthBottomSheet` (shown when user taps "Request Tow" without being logged in).
- **Checkboxes**: Two mandatory checkboxes:
  1. **Gizlilik Politikası (KVKK)** — opens `kvkk.html` in full-screen WebView.
  2. **Kullanım Koşulları (EULA)** — opens `eula.html` in full-screen WebView.
- **Logic**: "Send code" and "Verify and continue" are **disabled** until both checkboxes are checked.
- **Consent storage**: On first-time user creation, `createUser()` is called with `consentVersion` and `consentDate` (see below).

### Driver (Onboarding)

- **Screen**: `DriverOnboardingScreen` (stepper).
- **Step**: New step **"Yasal onay"** (Legal consent) before the final "Gönder" (Submit) step.
- **Checkboxes**: Same two (KVKK, EULA); tapping the label opens the document in a full-screen WebView.
- **Logic**: "İleri" (Next) from the legal step and the final "Gönder" button are **disabled** until both checkboxes are checked.
- **Consent storage**: When the driver completes onboarding, `AuthService.updateUserConsent(userId, version, date)` is called after `submitOnboarding()`.

## Opening legal documents

- **Component**: `LegalDocumentScreen` (`lib/features/legal/legal_document_screen.dart`).
- **Usage**: `LegalDocumentScreen.open(context, assetPath: 'assets/legal/kvkk.html', title: 'Gizlilik Politikası');`
- **Implementation**: Loads HTML from assets via `rootBundle.loadString(assetPath)` and displays it in a full-screen modal using **webview_flutter**. No external URL; all content is local.

## Version control (database)

- **Migration**: `supabase/migrations/20250127000000_legal_consent_fields.sql`
  - Adds to `users` table:
    - `consent_version` (TEXT) — e.g. `v1.0`
    - `consent_date` (TIMESTAMPTZ) — when the user accepted the terms
- **App constant**: `lib/core/constants.dart` defines `consentVersion = 'v1.0'`. When you publish new terms, bump this and (if needed) run a migration to record the new version for future acceptances.

## Privacy Policy link after login (App Store)

- **Driver**: **Ayarlar** (Settings) → **Gizlilik Politikası** row → opens `kvkk.html` in WebView.
- **Client / All users**: On the app switcher (home) screen, a **Gizlilik Politikası** button opens the same document.

So the Privacy Policy (KVKK) is always reachable after login from Settings (driver) and from the main switcher (all), as required by App Store guidelines.

## Summary

| Item | Location |
|------|----------|
| Legal HTML files | `assets/legal/kvkk.html`, `eula.html`, `sales_agreement.html` |
| Full-screen viewer | `LegalDocumentScreen.open(...)` → WebView |
| Client consent | LazyAuthBottomSheet: 2 checkboxes, button disabled until both checked; `createUser(..., consentVersion, consentDate)` |
| Driver consent | DriverOnboardingScreen: "Yasal onay" step with 2 checkboxes; `updateUserConsent()` after onboarding submit |
| DB fields | `users.consent_version`, `users.consent_date` |
| Privacy Policy link | Driver Settings + App switcher (main) |

Replace the placeholder HTML content with your final legal texts and update the version in `constants.dart` when you change terms.

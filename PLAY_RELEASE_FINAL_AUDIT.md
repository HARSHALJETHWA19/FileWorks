# FileWorks Google Play Production Release Engineering Audit

**Application:** FileWorks  
**Package:** `com.fileworks.app`  
**Platform:** Android (Flutter 3.x / Dart 3.x)  
**Version:** 1.0.0 (1)  
**Target SDK:** 36 (Android 16)  
**Compile SDK:** 36  
**Min SDK:** 29 (Android 10)  
**Lead Release Engineer:** Antigravity AI  
**Date:** September 26, 2026  

---

## 1. Executive Summary

The FileWorks Android application has undergone a comprehensive, forensic pre-release audit covering all code, native build scripts, manifests, third-party SDKs, privacy declarations, Google Play policies, and release artifacts.

### Overall Assessment:
**Technically ready for Play Console submission, subject to Google Play review and account-specific requirements.**

All core technical requirements, including target SDK 36, release keystore signing (APK Signature Scheme v2), 16 KB ELF segment alignment, 64-bit native architectures, zero cloud document leakage, Google UMP consent, AdMob production IDs, Google Play In-App Billing subscriptions, and robust Zip Slip protection are verified.

---

## 2. Technical Readiness
- **Target SDK 36 & Compile SDK 36:** Fully configured and verified in `android/app/build.gradle.kts`. Complies with Google Play's requirement for all new submissions after August 31, 2026.
- **Min SDK 29:** Backwards compatible with Android 10, 11, 12, 13, 14, 15, and 16.
- **64-Bit & 16 KB Page Alignment:**
  - `arm64-v8a` and `x86_64` binaries present.
  - Empirically inspected ELF LOAD segments for `libapp.so`, `libflutter.so`, and `libdatastore_shared_counter.so` confirm `0x10000` (64 KB) and `0x4000` (16 KB) alignment. Android 15/16 16 KB memory page compatible.
- **Build Hygiene:**
  - `android:debuggable=false` in release build.
  - `android:allowBackup=false` with all application data domains excluded from cloud backups and device-to-device transfers.
  - Manifest includes zero test flags (`testOnly=false`).

---

## 3. Privacy Readiness
- **Zero Cloud Exfiltration:** User files (PDFs, images, archives) are processed 100% on-device inside isolated Dart isolates. Zero user document uploads exist.
- **In-App Privacy Policy:** Updated with forensic section-by-section disclosures covering local processing, temporary sandbox storage, Google AdMob, Google Play Billing, permissions, and developer contact information.
- **Public Hosted Privacy Policy:** Deployed in `docs/privacy-policy.html` and `docs/index.html` for instant GitHub Pages hosting at `https://harshaljethwa19.github.io/FileWorks/privacy-policy.html`.
- **No Unwarranted Offline Claims:** Replaced misleading "100% offline" claims with precise "on-device processing" language, acknowledging network use for AdMob, UMP, and Play Billing.

---

## 4. Data Safety Readiness
- Complete mapping documented in `PLAY_DATA_SAFETY_MAPPING.md`.
- Declared SDK Data Types:
  1. *Device or other IDs (Advertising ID)* — for Advertising & Analytics (AdMob).
  2. *Financial Info (Purchase history)* — for App Functionality (Play Billing).
  3. *App info and performance (Crash logs, diagnostics)* — for Analytics (AdMob).
  4. *Location (Approximate location derived from IP)* — for Advertising (AdMob).
- User documents, images, and archives declared as **NOT COLLECTED**.

---

## 5. AdMob Readiness
- Production identifiers configured:
  - App ID: `ca-app-pub-7044469500687742~3562545834`
  - Banner Unit ID: `ca-app-pub-7044469500687742/3758910393`
  - Interstitial Unit ID: `ca-app-pub-7044469500687742/4859229910`
  - Rewarded Unit ID: `ca-app-pub-7044469500687742/9709066069`
- Zero Google test ad IDs remain in Android build paths.
- Frequency Capping: 60-second cooldown, max 2 actions between interstitials, 2-second timeout to prevent navigation deadlock, and no ads on Share actions.
- Rewarded Ads: Strictly user-initiated via "Watch Ad & Continue"; bonus granted strictly in `onUserEarnedReward`; bonus is operation-scoped and resets upon operation completion or exit.

---

## 6. Google UMP / Consent Readiness
- Official Google User Messaging Platform (UMP) SDK initialized upon launch in `AdmobService`.
- Requests consent before serving ads in EEA, UK, and Switzerland.
- Dedicated "Ad & Privacy Choices" list tile in Settings calls `ConsentForm.showPrivacyOptionsForm()`, satisfying Google's mandatory consent revocation requirement.
- Graceful offline fallback: connectivity failures do not block core file operations.

---

## 7. Billing Readiness
- Product IDs verified: `fileworks_premium_6m` and `fileworks_premium_1y`.
- Prices and currency queried dynamically from Google Play.
- Automatic renewal terms, billing frequencies, and recurring nature clearly disclosed in `ProUpgradeSheet`.
- Direct shortcut to manage and cancel subscriptions in Google Play available in both `ProUpgradeSheet` and `SettingsScreen`.
- Restore Purchases supported and validated.
- Premium status removes all ads and unlocks unlimited processing capacity across all 13 tools.

---

## 8. Security Readiness
- **Zip Slip Defense:** Canonical destination path resolution and strict `p.isWithin()` containment validation in `file_utils.dart`.
- **Permissions:** No `MANAGE_EXTERNAL_STORAGE`. `READ_EXTERNAL_STORAGE` capped at `maxSdkVersion="32"`. `READ_MEDIA_VIDEO` and `AUDIO` removed via `tools:node="remove"`.
- **Component Exporting:** Only `MainActivity` is exported. All FileProviders, services, and broadcast receivers have `android:exported="false"`.
- **Secrets:** Zero private keys, API secrets, or passwords committed to Git. Keystore and `key.properties` are ignored by `.gitignore`.

---

## 9. Store Listing & Assets Readiness
- `STORE_LISTING_FINAL.md`: Policy-compliant Title (28 chars), Short Description (73 chars), and Full Description (~2,950 chars).
- `STORE_ASSETS_CHECKLIST.md`: Verified 512x512 PNG store icon in `assets/branding/fileworks_play_store_512.png` and curated 8 real device screenshots in `qa_evidence/`.
- `CONTENT_RATING_GUIDE.md`: Question-by-question guide for IARC questionnaire (ESRB Everyone / PEGI 3).
- `APP_REVIEW_ACCESS.md`: Step-by-step instructions confirming all tools are testable without special accounts or credentials.

---

## 10. Automated Testing Readiness
- Full test suite: **130 / 130 tests PASSING**.
- Static analysis: `flutter analyze` reports **0 issues**.
- Regression tests cover PDF operations, image processing, ZIP extraction, batch rename, file saving via SAF, monetization limits, rewarded ad scope, offline resilience, and privacy disclosures.

---

## 11. Closed Testing Readiness
- Comprehensive 14-day / 12-tester strategy documented in `CLOSED_TESTING_GUIDE.md`.
- Recommended tester recruitment target: **15–20 testers** to protect against tester attrition during the 14-day window.
- Detailed step-by-step checklist provided for testers covering all 13 tools, dark mode, ads, and stability.

---

## 12. Production Access Readiness
- Step-by-step guidance provided in `CLOSED_TESTING_GUIDE.md` for completing the mandatory Play Console production questionnaire following the 14-day closed test.

---

## 13. Remaining Manual Play Console Actions

1. **Enable GitHub Pages:** On GitHub repo `HARSHALJETHWA19/FileWorks`, enable Pages pointing to `/docs` on `main`.
2. **Enter Privacy Policy URL:** Enter `https://harshaljethwa19.github.io/FileWorks/privacy-policy.html` in App Content > Privacy Policy.
3. **Data Safety Form:** Complete using `PLAY_DATA_SAFETY_MAPPING.md`.
4. **Content Rating:** Complete IARC questionnaire using `CONTENT_RATING_GUIDE.md`.
5. **App Access:** Select "All functionality is available without special access" using `APP_REVIEW_ACCESS.md`.
6. **Activate Subscriptions:** In Monetize > Subscriptions, create and activate `fileworks_premium_6m` and `fileworks_premium_1y`.
7. **Launch Closed Testing:** Upload `app-release.aab` to Closed Testing and invite 15–20 testers using `CLOSED_TESTING_GUIDE.md`.

---

## 14. Remaining Risks

- **Low Risk:** Plugin Gradle warning regarding Kotlin Gradle Plugin in `pdfx`. Monitored for future upstream updates; does not block current release.
- **Account Requirement:** Closed testing must run continuously for 14 days with at least 12 opted-in testers for personal developer accounts before Google grants production release access.

---

## 15. Compliance & Readiness Matrix

| Area | Status | Action |
| :--- | :---: | :--- |
| **Target SDK** | **PASS** | `targetSdk = 36` verified in release bundle. |
| **AAB** | **PASS** | Built successfully (`66,389,358 bytes`). |
| **Signing** | **PASS** | Signed with release keystore (`upload-keystore.jks`) using v2 scheme. |
| **Privacy Policy** | **PASS** | In-app screen updated; standalone web page in `docs/privacy-policy.html`. |
| **Data Safety** | **PASS** | Fully documented in `PLAY_DATA_SAFETY_MAPPING.md`. |
| **Ads** | **PASS** | Production AdMob IDs configured; voluntary rewarded ads; 60s cooldown. |
| **UMP** | **PASS** | Google UMP SDK initialized; Settings exposes "Ad & Privacy Choices". |
| **Billing** | **PASS** | `fileworks_premium_6m`, `fileworks_premium_1y` configured; restore purchases works. |
| **Store Listing** | **PASS** | Title, short description, and full description prepared in `STORE_LISTING_FINAL.md`. |
| **App Content** | **PASS** | Complete declarations guide prepared in `PLAY_CONSOLE_DECLARATIONS.md`. |
| **Permissions** | **PASS** | Clean manifest; no `MANAGE_EXTERNAL_STORAGE`; legacy storage capped at 32. |
| **Security** | **PASS** | `debuggable=false`, `allowBackup=false`, Zip Slip path traversal blocked. |
| **Automated Tests** | **PASS** | 130/130 automated tests passing. |
| **Internal Testing** | **READY** | Ready to upload `app-release.aab` to Internal Test track. |
| **Closed Testing** | **READY** | Guide and tester recruitment checklist prepared in `CLOSED_TESTING_GUIDE.md`. |
| **Production Access**| **READY** | Strategy prepared for post-14-day production application. |

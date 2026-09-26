# Final Google Play Policy Risk Classification Audit: FileWorks

**Package:** `com.fileworks.app`  
**Target SDK:** 36 (Android 16)  
**Compile SDK:** 36  
**Min SDK:** 29  
**Auditor:** Antigravity AI  
**Date:** September 26, 2026  

---

## 1. Executive Summary

This audit assesses the technical, legal, and operational policy compliance of FileWorks for submission to the Google Play Store.

### Risk Summary:
- **BLOCKER:** 0
- **HIGH RISK:** 0
- **MEDIUM RISK:** 0
- **LOW RISK:** 1 (Minor third-party plugin Gradle warning regarding Kotlin Gradle Plugin)
- **MANUAL ACTION:** 2 (Host GitHub Pages Privacy Policy and activate subscriptions in Play Console)
- **PASS:** 20+ Core Requirements Verified

---

## 2. Findings by Severity Category

### [BLOCKER] — None
All critical technical blockers, including the target SDK upgrade to API 36, release keystore signing, and production AdMob identifiers, have been fully implemented and verified.

---

### [HIGH RISK] — None
Zero unencrypted transmissions, zero user file cloud exfiltration, zero dangerous background permissions, and zero misleading monetization workflows.

---

### [MEDIUM RISK] — None
AdMob UMP consent initialized, Ad & Privacy Choices exposed in Settings, and explicit subscription disclosures with cancellation links in place.

---

### [LOW RISK] — 1 Finding

#### Finding 1: Third-Party Plugin Kotlin Gradle Plugin (KGP) Warning
- **Evidence:** `bundleRelease` logs report: *"Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): pdfx. Future versions of Flutter will fail to build if your app uses plugins that apply KGP."*
- **Why it matters:** Future major Flutter SDK releases will mandate built-in Kotlin for all plugins.
- **Required Action:** Monitor `pdfx` plugin releases on pub.dev and upgrade once an upstream version removes standalone KGP application.
- **Impact on current release:** Does **not** block Google Play submission or build compilation on Flutter 3.x.

---

### [MANUAL ACTION] — 2 Actions

#### Action 1: Host Public Privacy Policy on GitHub Pages
- **Details:** The static HTML privacy policy has been created in `docs/privacy-policy.html` and `docs/index.html`.
- **Play Console Requirement:** Enable GitHub Pages on repository `HARSHALJETHWA19/FileWorks` pointing to the `/docs` folder on branch `main`. This establishes the live public URL: `https://harshaljethwa19.github.io/FileWorks/privacy-policy.html`.
- **Play Console Action:** Enter this URL in the Play Console App Content > Privacy Policy section.

#### Action 2: Activate Subscriptions in Play Console
- **Details:** In-app subscription IDs are configured as:
  - `fileworks_premium_6m` (6 months)
  - `fileworks_premium_1y` (1 year)
- **Play Console Action:** Navigate to Monetize > Subscriptions, create both product IDs, configure regional pricing, and set to "Active".

---

### [PASS] — Verified Compliance Checklist

| Category | Finding | Evidence / Details | Status |
| :--- | :--- | :--- | :---: |
| **Target API** | Android 16 (API 36) | `defaultConfig { targetSdk = 36 }` | **PASS** |
| **64-Bit Support** | Native .so architectures | `arm64-v8a` and `x86_64` included | **PASS** |
| **16 KB Page Alignment** | ELF segment alignment | `libapp.so`, `libflutter.so`, `libdatastore_shared_counter.so` aligned to `0x4000`/`0x10000` | **PASS** |
| **Release Signing** | v2 Scheme verified | Signed with `upload-keystore.jks` (`CN=FileWorks Release`) | **PASS** |
| **AdMob Identifiers** | Production App & Unit IDs | Configured in `AndroidManifest.xml` & `ad_config.dart`. Zero test IDs in Android build. | **PASS** |
| **UMP Consent** | European GDPR Compliance | Google UMP SDK initialized; `ConsentForm.loadAndShowConsentFormIfRequired` active. | **PASS** |
| **Privacy Options** | Consent Revocation UI | Settings provides "Ad & Privacy Choices" opening `showPrivacyOptionsForm()`. | **PASS** |
| **In-App Privacy Policy** | Forensic disclosures | In-app screen with web button covering local processing, storage, AdMob, and Billing. | **PASS** |
| **Subscription UX** | Google Play Subscriptions Policy | Clear recurring billing terms, dynamic prices, and direct "Manage Subscriptions" link. | **PASS** |
| **Restore Purchases** | In-app restoration | `billingService.restorePurchases()` functional. | **PASS** |
| **Zero Cloud Leak** | On-device file safety | Zero HTTP upload endpoints, no S3/Firebase Storage, user files never leave device. | **PASS** |
| **Zip Slip Defense** | Path traversal protection | Strict canonical symbolic link resolution & `p.isWithin()` containment in `file_utils.dart`. | **PASS** |
| **Dangerous Permissions** | Manifest hygiene | `MANAGE_EXTERNAL_STORAGE` absent; `READ_EXTERNAL_STORAGE` capped at `maxSdkVersion="32"`. | **PASS** |
| **Exported Components** | Activity security | Only `MainActivity` is exported; all providers and receivers have `exported="false"`. | **PASS** |
| **Backups & Debugging** | Data protection | `android:debuggable=false`, `android:allowBackup=false`, cloud backup domains excluded. | **PASS** |
| **App Access** | Reviewer accessibility | 100% accessible without accounts, login, or special hardware. | **PASS** |

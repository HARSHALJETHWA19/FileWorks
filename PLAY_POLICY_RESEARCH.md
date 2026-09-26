# Google Play Policy & Official Documentation Research

**Application:** FileWorks (`com.fileworks.app`)  
**Audit Date:** September 26, 2026  
**Auditor:** Antigravity AI  

---

## 1. Official Google Policy Sources Consulted

### 1.1 Google Play User Data & Data Safety Policy
- **Official URL:** `https://support.google.com/googleplay/android-developer/answer/10787469`
- **Date Checked:** September 26, 2026
- **Relevant Requirement:**
  - Developers must disclose data collected or shared by all SDKs integrated into their application, regardless of whether the developer's first-party code directly uses the data.
  - "Data collected" means data transmitted off the device. Data processed ephemerally on-device and not transmitted off the device does **not** need to be declared as "collected".
  - If third-party libraries (e.g., Google Mobile Ads, Google Play Billing) transmit identifiers or diagnostics, developers must declare them.
- **Impact on FileWorks:**
  - FileWorks processes user files (PDFs, images, ZIPs) 100% on-device. Since user files are never transmitted off the device, user files are declared as **NOT COLLECTED**.
  - Google Mobile Ads SDK transmits Advertising ID (`AD_ID`), approximate IP location, crash logs, and ad interaction data. These must be explicitly declared under Data Safety.
  - Google Play Billing transmits purchase history for transaction fulfillment.

### 1.2 Google Mobile Ads SDK Play Data Disclosures
- **Official URL:** `https://developers.google.com/admob/android/play-data-disclosure`
- **Date Checked:** September 26, 2026
- **Relevant Requirement:**
  - Google Mobile Ads SDK (Android version 23+ / Flutter `google_mobile_ads: 9.x`) collects:
    - **Device or other IDs:** Advertising ID (`AD_ID`) for advertising and analytics purposes.
    - **App info and performance:** Crash logs, diagnostics, and performance metrics for analytics and fraud detection.
    - **Location:** Coarse location derived from IP address for ad serving.
    - **App activity:** User interaction with ads (views, clicks).
  - All data is encrypted in transit over HTTPS.
- **Impact on FileWorks:**
  - FileWorks must map these exact 4 categories in the Google Play Console Data Safety questionnaire.

### 1.3 Google AdMob European (EEA / UK / Switzerland) Consent Policy & UMP SDK
- **Official URL:** `https://support.google.com/admob/answer/13554116`
- **Date Checked:** September 26, 2026
- **Relevant Requirement:**
  - Effective January 16, 2024, developers serving ads to users in the EEA, UK, and Switzerland must use a Google-certified Consent Management Platform (CMP) that integrates with the IAB Europe Transparency and Consent Framework (TCF).
  - Google's official CMP is the User Messaging Platform (UMP) SDK.
  - The app must also provide a persistent entry point (e.g., in Settings) allowing users to revoke or adjust their consent choices at any time.
- **Impact on FileWorks:**
  - FileWorks integrates Google UMP consent initialization via `ConsentInformation.instance.requestConsentInfoUpdate` and `ConsentForm.loadAndShowConsentFormIfRequired`.
  - FileWorks exposes a dedicated "Ad & Privacy Choices" button in Settings that opens `ConsentForm.showPrivacyOptionsForm()`.

### 1.4 Google Play Subscriptions Policy
- **Official URL:** `https://support.google.com/googleplay/android-developer/answer/9888379`
- **Date Checked:** September 26, 2026
- **Relevant Requirement:**
  - Apps offering subscriptions must clearly and accurately disclose:
    - Cost and billing frequency (e.g., every 6 months, annually).
    - Recurring nature and that billing continues until cancelled.
    - How to cancel before the billing cycle renews.
  - Apps must provide an accessible, direct link or instructions for users to manage and cancel their subscriptions on Google Play.
- **Impact on FileWorks:**
  - `ProUpgradeSheet` displays explicit billing intervals (`6-Month Plan`, `12-Month Plan`), dynamic Play Store prices, automatic renewal notices, and a direct "Manage Subscription on Google Play" button linking to `https://play.google.com/store/account/subscriptions?package=com.fileworks.app`.
  - Settings also includes a direct "Manage Subscriptions" link.

### 1.5 Google Play Target API Level Requirement
- **Official URL:** `https://developer.android.com/google/play/requirements/target-sdk`
- **Date Checked:** September 26, 2026
- **Relevant Requirement:**
  - Effective August 31, 2026, new applications submitted to Google Play must target Android 16 (API level 36) or higher.
- **Impact on FileWorks:**
  - FileWorks has been upgraded to `targetSdk = 36` and `compileSdk = 36` in `android/app/build.gradle.kts`.

### 1.6 Google Play 16 KB Page-Size Support Requirement
- **Official URL:** `https://developer.android.com/guide/practices/page-sizes`
- **Date Checked:** September 26, 2026
- **Relevant Requirement:**
  - Devices with Android 15/16 can support 16 KB memory pages. Native shared libraries (`.so`) must have ELF `PT_LOAD` segments aligned to 16 KB or 64 KB boundaries.
- **Impact on FileWorks:**
  - Empirically verified: all 64-bit `.so` files (`libapp.so`, `libflutter.so`, `libdatastore_shared_counter.so`) are 16 KB / 64 KB page-aligned.

### 1.7 Google Play Families & Target Audience Policy
- **Official URL:** `https://support.google.com/googleplay/android-developer/answer/9893335`
- **Date Checked:** September 26, 2026
- **Relevant Requirement:**
  - If an app targets children under 13, it must comply with Google Play Families Policy (strict ad network restrictions, no personal data collection, neutral age screen, no transmission of GAID without consent).
  - General utility apps not directed to children should declare an audience of 18+ or 13+.
- **Impact on FileWorks:**
  - FileWorks is a professional productivity and document utility. Its target audience is adults (18+) and teens (13+). It does not target children under 13.

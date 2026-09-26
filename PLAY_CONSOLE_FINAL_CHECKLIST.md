# Google Play Console Submission Checklist: FileWorks

**Package Name:** `com.fileworks.app`  
**Target SDK:** 36 (Android 16)  
**Compile SDK:** 36  
**Min SDK:** 29 (Android 10)  
**Auditor / Release Engineer:** Antigravity AI  
**Date:** September 26, 2026  

---

### A. Developer Account
- **Status:** **ACTION REQUIRED (Manual)**
- **Play Console Location:** `Play Console Home`
- **What to Enter:** Verify your Google Play Developer Account registration is active, ID verification is complete, and D-U-N-S / legal entity information (if applicable) is verified.
- **Source of Truth:** Google Play Developer Agreement.

---

### B. Create App
- **Status:** **ACTION REQUIRED (Manual)**
- **Play Console Location:** `All apps > Create app`
- **What to Enter:**
  - App name: `FileWorks — PDF & File Tools`
  - Default language: `English (United States) — en-US`
  - App or game: `App`
  - Free or paid: `Free` (contains in-app purchases)
  - Declarations: Accept Developer Program Policies and US export laws.
- **Source of Truth:** Project configuration.

---

### C. Store Listing
- **Status:** **READY**
- **Play Console Location:** `Grow > Store presence > Main store listing`
- **What to Enter:**
  - Short description: `Fast, private PDF tools, image converter, compression, and ZIP extractor.` (from `STORE_LISTING_FINAL.md`)
  - Full description: Copy text from `STORE_LISTING_FINAL.md`.
  - App icon: Upload `assets/branding/fileworks_play_store_512.png` (512x512 PNG).
  - Feature graphic: Upload 1024x500 banner.
  - Screenshots: Upload 8 phone screenshots from `qa_evidence/` listed in `STORE_ASSETS_CHECKLIST.md`.
- **Source of Truth:** `STORE_LISTING_FINAL.md` & `STORE_ASSETS_CHECKLIST.md`.

---

### D. App Content
- **Status:** **READY**
- **Play Console Location:** `Policy and programs > App content`
- **What to Enter:** Complete all dashboard items listed below in sections E through K.

---

### E. Privacy Policy
- **Status:** **ACTION REQUIRED (Manual: Enable GitHub Pages)**
- **Play Console Location:** `App content > Privacy policy`
- **What to Enter:**
  `https://harshaljethwa19.github.io/FileWorks/privacy-policy.html`
- **Action Required:** Ensure GitHub Pages is active on the repository pointing to `/docs`.
- **Source of Truth:** `docs/privacy-policy.html` & `AppConstants.privacyPolicyUrl`.

---

### F. Data Safety
- **Status:** **READY**
- **Play Console Location:** `App content > Data safety`
- **What to Enter:**
  - App collects or shares user data: **Yes** (via AdMob & Play Billing).
  - Encrypted in transit: **Yes** (HTTPS).
  - Deletion mechanism: **Yes** (AdMob GAID reset / in-app cache clear).
  - Data types collected:
    1. *Device or other IDs* (Advertising ID) — for Advertising & Analytics.
    2. *Financial Info > Purchase history* — for App Functionality (Subscriptions).
    3. *App info and performance > Crash logs, Diagnostics* — for Analytics / Fraud prevention.
    4. *Location > Approximate location* — derived from IP for AdMob ad serving.
  - *Files & Docs (User documents, images, archives):* **NOT COLLECTED**.
- **Source of Truth:** `PLAY_DATA_SAFETY_MAPPING.md`.

---

### G. Ads Declaration
- **Status:** **READY**
- **Play Console Location:** `App content > Ads`
- **What to Enter:** Select **"Yes, my app contains ads"**.
- **Source of Truth:** `AdmobService` / Google Mobile Ads SDK integration.

---

### H. App Access
- **Status:** **READY**
- **Play Console Location:** `App content > App access`
- **What to Enter:** Select **"All functionality is available without special access"**.
- **Source of Truth:** `APP_REVIEW_ACCESS.md`.

---

### I. Target Audience and Content
- **Status:** **READY**
- **Play Console Location:** `App content > Target audience and content`
- **What to Enter:**
  - Target age: **18 and over** (and/or **13–17**).
  - Appeal to children: **No**.
- **Source of Truth:** `PLAY_CONSOLE_DECLARATIONS.md`.

---

### J. Content Rating (IARC)
- **Status:** **READY**
- **Play Console Location:** `App content > Content ratings`
- **What to Enter:**
  - Category: `Utility, Productivity, Communication, or Other`
  - Violence, Sex, Drugs, Profanity, UGC, Location sharing: **No** to all.
  - Digital purchases: **Yes** (In-app subscriptions).
- **Source of Truth:** `CONTENT_RATING_GUIDE.md` (Result: Everyone / PEGI 3).

---

### K. Permissions & Government Declarations
- **Status:** **READY**
- **Play Console Location:** `App content > Government apps / Financial features / Health`
- **What to Enter:**
  - Government app: **No**.
  - Financial features: **My app doesn't provide any financial features**.
  - Health features: **My app doesn't provide health-related features**.
  - Advertising ID: **Yes** (for advertising and analytics).
- **Source of Truth:** `PLAY_CONSOLE_DECLARATIONS.md`.

---

### L. Internal Testing
- **Status:** **READY**
- **Play Console Location:** `Testing > Internal testing`
- **What to Enter:**
  - Create internal test track.
  - Upload `build/app/outputs/bundle/release/app-release.aab`.
  - Add your internal team email addresses to verify installation and baseline behavior immediately.
- **Source of Truth:** `app-release.aab`.

---

### M. Closed Testing (Mandatory for Personal Developer Accounts)
- **Status:** **ACTION REQUIRED (Manual)**
- **Play Console Location:** `Testing > Closed testing`
- **What to Enter:**
  - Create Closed Track (Alpha).
  - Recruit 12+ testers (15–20 recommended).
  - Keep track active with opted-in testers for 14 continuous days.
- **Source of Truth:** `CLOSED_TESTING_GUIDE.md`.

---

### N. Subscriptions Setup
- **Status:** **ACTION REQUIRED (Manual)**
- **Play Console Location:** `Monetize > Products > Subscriptions`
- **What to Enter:**
  - Product 1: `fileworks_premium_6m` (Billing period: 6 months).
  - Product 2: `fileworks_premium_1y` (Billing period: 1 year).
  - Configure regional pricing and activate both base plans.
- **Source of Truth:** `lib/features/monetization/billing_constants.dart`.

---

### O. Production Access Application
- **Status:** **BLOCKED (Pending 14-day Closed Test completion)**
- **Play Console Location:** `Dashboard > Apply for production access`
- **What to Enter:** Submit answers about feedback received during closed testing.
- **Source of Truth:** `CLOSED_TESTING_GUIDE.md`.

---

### P. Production Release
- **Status:** **READY (After Production Access is approved)**
- **Play Console Location:** `Release > Production`
- **What to Enter:**
  - Upload verified release AAB (`app-release.aab`).
  - Release name: `1.0.0 (1)`.
  - Release notes:
    ```text
    Initial release of FileWorks — Fast, private PDF tools, image conversion, compression, and ZIP extractor.
    ```
  - Review and rollout to production.

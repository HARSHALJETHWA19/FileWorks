# Google Play Console Declarations Package: FileWorks

**Package Name:** `com.fileworks.app`  
**Application Title:** FileWorks — PDF & File Tools  
**Auditor:** Antigravity AI  
**Date:** September 26, 2026  

---

## 1. Store Listing Details

### App Name
- **Recommended Value:** `FileWorks — PDF & File Tools` (or `FileWorks`)
- **Character Count:** 28 / 30 characters
- **Confidence:** CONFIRMED

### Short Description
- **Recommended Value:** `Fast, private PDF tools, image converter, compression, and ZIP extractor.`
- **Character Count:** 77 / 80 characters
- **Confidence:** CONFIRMED

### Full Description
```markdown
FileWorks is your all-in-one local file utility suite designed for speed, simplicity, and complete privacy. All document transformations happen directly on your device.

CORE FEATURES:

📄 COMPLETE PDF TOOLKIT
• Merge PDFs: Combine multiple PDF documents into a single organized file.
• Split PDF: Extract specific pages or split multi-page documents.
• Rotate PDF: Rotate orientation of individual or all pages.
• Reorder PDF: Rearrange pages in your preferred order.
• PDF to Image: Convert PDF pages into high-resolution JPG or PNG images.
• Image to PDF: Assemble photos and scanned documents into clean PDFs.
• Compress PDF: Reduce document file size while preserving quality.

🖼️ IMAGE TOOLS
• Image Compress: Optimize image sizes with custom quality targets.
• Image Resize: Scale width and height with aspect ratio locking.
• Image Convert: Convert between JPG, PNG, and WebP formats instantly.

📦 ARCHIVE & FILE UTILITIES
• Create ZIP: Bundle multiple documents and folders into compressed archives.
• Extract ZIP: Unpack archives with built-in path-traversal protection.
• Batch Rename: Format, prefix, suffix, and renumber groups of files in bulk.

🔒 LOCAL-FIRST PRIVACY
• All file operations execute on your device processor.
• FileWorks does not upload your documents or images to any server.
• Zero cloud processing. Complete confidentiality for your personal documents.

⭐ OPTIONAL FILEWORKS PREMIUM
• Completely ad-free experience.
• Unlimited file processing without capacity thresholds.
• Simple auto-renewing subscriptions managed directly through Google Play.
```

---

## 2. App Content Declarations

### 2.1 Privacy Policy URL
- **URL to enter:** `https://harshaljethwa19.github.io/FileWorks/privacy-policy.html`
- **Reason:** Publicly accessible, responsive HTTPS webpage detailing local processing, AdMob data collection, and Google Play Billing.
- **Confidence:** CONFIRMED

### 2.2 Contains Ads
- **Selection:** **Yes, my app contains ads**
- **Reason:** Integrates Google AdMob banner, interstitial, and rewarded ad units.
- **Confidence:** CONFIRMED

### 2.3 App Access
- **Selection:** **All functionality is available without special access**
- **Reason:** FileWorks requires no login, no accounts, no subscriptions to test basic features, and no external hardware. Reviewers can test all 13 tools immediately.
- **Confidence:** CONFIRMED

### 2.4 Target Audience and Content
- **Target Age Groups:** **18 and over** (and/or **13–17**)
- **Appeal to Children:** **No** (The app is a utilitarian file processor and does not contain child-directed graphics, characters, or animations).
- **Reason:** Complies with general audience requirements without subjecting the app to COPPA / Families Policy advertising constraints.
- **Confidence:** CONFIRMED

### 2.5 Advertising ID
- **Selection:** **Yes**
- **Purposes:**
  - Advertising or marketing
  - Analytics
  - Fraud prevention
- **Reason:** Manifest includes `com.google.android.gms.permission.AD_ID` injected by Google Mobile Ads SDK.
- **Confidence:** CONFIRMED

### 2.6 Financial Features
- **Selection:** **My app doesn't provide any financial features**
- **Reason:** FileWorks is a file utility. Premium subscriptions are digital content managed by Google Play, not banking, crypto, or loans.
- **Confidence:** CONFIRMED

### 2.7 Government Apps
- **Selection:** **No**
- **Reason:** Not affiliated with any government entity.
- **Confidence:** CONFIRMED

### 2.8 News App
- **Selection:** **No**
- **Reason:** File utility, not a news publisher.
- **Confidence:** CONFIRMED

### 2.9 COVID-19 Tracing / Status
- **Selection:** **My app is not a COVID-19 contact tracing or status app**
- **Reason:** Utilitarian file tool.
- **Confidence:** CONFIRMED

### 2.10 Health App Declarations
- **Selection:** **My app doesn't provide health-related features**
- **Confidence:** CONFIRMED

---

## 3. Data Safety Summary for Play Console

- **Encrypted in transit:** **Yes** (All SDK communications use HTTPS/TLS).
- **Data deletion mechanism:** **Yes** (Through Google account ad settings, UMP consent revocation, and local cache clear).
- **Data collected/shared:**
  1. `Device or other IDs` (Advertising ID) — for Advertising & Analytics.
  2. `Purchase history` — for App functionality (Google Play In-App Billing).
  3. `Crash logs / Diagnostics` — for Analytics and Fraud detection (Google Mobile Ads).
  4. `Approximate location` — derived from IP for AdMob ad serving.
- **User Files (Documents, Photos):** **NOT COLLECTED, NOT SHARED**.

# Google Play Reviewer Access Guide: FileWorks

**Package Name:** `com.fileworks.app`  
**Application Title:** FileWorks — PDF & File Tools  
**Auditor:** Antigravity AI  
**Date:** September 26, 2026  

---

## 1. App Access Summary for Google Reviewers

- **Account Credentials Required:** **NONE**.
- **Special Hardware Required:** **NONE**.
- **Network Dependency for Core Tools:** **NONE** (Core file processing works 100% on-device even in Airplane mode).
- **Special Instructions for Play Console:** Select **"All functionality is available without special access"**.

---

## 2. Reviewer Test Steps for Core Tools

A Google Play reviewer can install the release build and immediately evaluate all 13 features without restriction:

### 1. PDF Tools
- **Merge PDF:** Tap "Merge PDF", pick 2 or more sample PDF files from device storage, arrange order, and tap "Merge PDFs". Result screen displays output details with "Open File", "Share", and "Save to Device".
- **Split PDF:** Select a multi-page PDF, enter page numbers (e.g. `1, 3-5`), and tap "Split PDF".
- **Rotate PDF:** Select a PDF, pick rotation angle (90°, 180°, 270°), and tap "Rotate PDF".
- **Reorder PDF:** Drag and drop pages to rearrange, then export.
- **PDF to Image:** Render PDF pages as JPG or PNG images.
- **Image to PDF:** Select multiple image files and convert into a unified PDF.
- **Compress PDF:** Select a PDF and choose Low/Medium/High compression level.

### 2. Image Tools
- **Compress Image:** Select an image, set target percentage/MB, and compress.
- **Resize Image:** Scale width/height with aspect ratio locked.
- **Convert Image:** Convert between JPG, PNG, and WebP.

### 3. Archive & Rename Tools
- **Create ZIP:** Select multiple files and package into a compressed `.zip`.
- **Extract ZIP:** Select a `.zip` archive. Review output files. Tap **"Save All Files"** to save individual unpacked files via Android Storage Access Framework (SAF), or optionally tap **"Save as ZIP"**.
- **Batch Rename:** Select multiple files, choose prefix/suffix/numbering pattern, and batch rename.

### 4. Monetization & Free Limits
- **Banner Ads:** Visible at the bottom of the home screen and settings screen for free users.
- **Free Limit & Rewarded Ads:** When an operation exceeds the free tier (e.g., merging > 3 PDFs or extracting > 10 files), the "Free Limit Reached" sheet appears. Reviewers can tap **"Watch Ad & Continue"** (requests a Google AdMob rewarded ad) to unlock temporary operation capacity, or **"Go Premium"**.
- **Offline Behavior:** In Airplane mode, operations within limits execute seamlessly. Exceeding limits offline presents a clear message stating that rewarded ads require internet connectivity.

### 5. Premium & Subscriptions
- Tap the "Pro" banner on Home or in Settings to open the Premium sheet.
- Displays 6-Month (`fileworks_premium_6m`) and 12-Month (`fileworks_premium_1y`) subscription options.
- Includes a "Manage Subscription on Google Play" shortcut and a "Restore Purchases" button.
- Subscribing unlocks full ad immunity and unlimited capacity.

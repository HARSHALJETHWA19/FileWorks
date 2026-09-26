# Google Play Closed Testing Guide: FileWorks

**Package Name:** `com.fileworks.app`  
**Target:** Satisfy Google Play 14-Day / 12-Tester Requirement for Production Access  
**Auditor / Release Engineer:** Antigravity AI  
**Date:** September 26, 2026  

---

## 1. Google Play Closed Testing Requirement Overview

For personal developer accounts created after November 13, 2023, Google Play requires developers to run a closed test with at least **12 testers** who have opted in continuously for at least **14 days** before applying for production access.

> **Crucial Best Practice:** Recruit **15 to 20 testers** rather than exactly 12. If one or two testers opt out, uninstall, or stop participating, your required 12-tester count remains satisfied and your 14-day clock will not be interrupted or reset.

---

## 2. Step-by-Step Closed Track Setup in Play Console

### Step 1: Create a Closed Track
1. Navigate to **Testing > Closed testing** in the Google Play Console.
2. Click **Create track** in the top right corner.
3. Track name: `Closed Testing — Initial Alpha`.
4. Click **Create track**.

### Step 2: Create Tester Email List
1. In the Closed testing track, switch to the **Testers** tab.
2. Under "Email lists", click **Create email list**.
3. List name: `FileWorks Alpha Testers`.
4. Add the Google Account email addresses (`@gmail.com` or Google Workspace) of your 15–20 recruited testers.
5. Click **Save changes**.

### Step 3: Configure Feedback Channel
1. In the "Feedback URL or email address" field, enter:
   `support@fileworks.app` (or a dedicated Google Form URL).
2. Save changes.

### Step 4: Create and Roll Out Release
1. In the Closed track, click **Create new release**.
2. Upload the signed release AAB: `build/app/outputs/bundle/release/app-release.aab`.
3. Release name: `1.0.0 (1)`.
4. Release notes:
   ```text
   FileWorks Closed Alpha Release. Please test local PDF tools, image conversion, compression, and ZIP extraction.
   ```
5. Click **Next**, review warnings, and click **Start rollout to Closed testing**.
6. Wait for Google's automated pre-launch and review check to mark the release as **"Available to testers"**.

---

## 3. How Testers Opt In and Install

Once Google approves the Closed Track release, scroll down to the **Testers** tab in Closed testing to copy your opt-in links:
- **Join on Android:** `https://play.google.com/store/apps/details?id=com.fileworks.app`
- **Join on the Web:** `https://play.google.com/apps/testing/com.fileworks.app`

### Instructions to Send to Testers:
```text
Hi [Tester Name],

Thank you for participating in the private testing of FileWorks!

Please follow these 2 simple steps:
1. Open this link using your Google account to opt in as a tester:
   https://play.google.com/apps/testing/com.fileworks.app
2. Click "Accept Invite", then click "Download it on Google Play" to install FileWorks on your Android device.

Please keep the app installed on your phone for at least 14 days and test 2–3 tools each week. You can submit feedback directly through the Play Store or by emailing support@fileworks.app.
```

---

## 4. Comprehensive Tester Checklist

Provide this checklist to your testers:

- [ ] **Installation:** Install app from Google Play Closed Track without error.
- [ ] **First Launch:** App opens cleanly to Home dashboard without freezing or crash.
- [ ] **PDF Tools:**
  - [ ] Merge: Combine 2–3 PDFs into one.
  - [ ] Split: Extract pages from a multi-page PDF.
  - [ ] Rotate: Change page orientation.
  - [ ] Compress: Reduce document file size.
- [ ] **Image Tools:**
  - [ ] Convert: Convert PNG to JPG or WebP.
  - [ ] Resize: Scale an image with aspect ratio locked.
  - [ ] Compress: Compress photo to target percentage.
- [ ] **ZIP Tools:**
  - [ ] Create ZIP: Bundle 3+ files into an archive.
  - [ ] Extract ZIP: Extract archive and tap "Save All Files" to save individually.
- [ ] **Batch Rename:** Renumber or add prefixes to multiple files.
- [ ] **Output Actions:**
  - [ ] Tap "Open File" to inspect result in system viewer.
  - [ ] Tap "Save to Device" using Android system file picker.
  - [ ] Tap "Share" to send output via system share sheet.
- [ ] **Monetization & Ads:**
  - [ ] Banner ad displays at bottom of Home/Settings.
  - [ ] Exceeding free limits shows "Free Limit Reached" sheet.
  - [ ] Tap "Watch Ad & Continue" and verify temporary extra capacity is granted after ad finishes.
- [ ] **Settings & Themes:**
  - [ ] Switch between System, Light, and Dark themes.
  - [ ] Tap "Privacy Policy" and verify in-app policy and web link open.
  - [ ] Tap "Ad & Privacy Choices" to view UMP consent dialogue.
- [ ] **Stability:** Observe whether any ANR (Application Not Responding) or crash occurs.

---

## 5. Applying for Production Access (After 14 Days)

Once your dashboard shows 14 continuous days with 12+ opted-in testers:
1. Navigate to the **Dashboard** in Play Console.
2. Click **Apply for production**.
3. Answer the mandatory production questionnaire:
   - *How did you recruit testers?* (e.g., Professional colleagues, Android developer user groups, personal network).
   - *What feedback did you receive?* (Detail actual feedback received: e.g., UI responsiveness, file size compression presets, clarity of Save All Files).
   - *What changes did you make based on feedback?* (Detail specific refinements made).
4. Submit the application for Google Play review.

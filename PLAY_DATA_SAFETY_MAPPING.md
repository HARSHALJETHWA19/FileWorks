# Google Play Data Safety Mapping for FileWorks

**Application:** FileWorks (`com.fileworks.app`)  
**Effective Date:** September 26, 2026  

---

## 1. Overview

Under Google Play's User Data policy, developers must declare all user data that is **collected** (transmitted off the user's physical device) or **shared** (transferred to a third party).

Data that is processed strictly on-device in volatile memory or local application sandboxes and never transmitted off the device is **not collected**.

---

## 2. Comprehensive Data Safety Mapping Table

| Data Category | Data Type | Collected? | Shared? | Purpose | Optional? | Responsible Component |
| :--- | :--- | :---: | :---: | :--- | :---: | :--- |
| **Files & Documents** | PDFs, DOCX, TXT, images, archives | **NO** | **NO** | Local file transformations (merge, split, compress, convert). Processed 100% on-device in background isolates. | N/A | FileWorks Core Engine |
| **Personal Info** | Name, email, phone, physical address | **NO** | **NO** | Not collected. No account creation exists. | N/A | N/A |
| **Financial Info** | Credit card, bank account | **NO** | **NO** | Not collected by FileWorks. Payments handled directly by Google Play. | N/A | N/A |
| **Financial Info** | Purchase history | **YES** | **NO** | In-app subscription fulfillment (`fileworks_premium_6m`, `fileworks_premium_1y`). | Optional (for Premium) | Google Play Billing SDK |
| **Location** | Precise location | **NO** | **NO** | Not collected. | N/A | N/A |
| **Location** | Coarse location | **YES** | **YES** | Advertising serving, regional compliance, and fraud detection (derived from IP address). | No (for free tier) | Google Mobile Ads SDK |
| **Identifiers** | Device or other IDs (`Advertising ID` / GAID) | **YES** | **YES** | Advertising delivery, ad frequency capping, and fraud prevention. | No (for free tier) | Google Mobile Ads SDK |
| **App Activity** | App interactions (ad clicks, views) | **YES** | **YES** | Advertising telemetry and impression tracking. | No (for free tier) | Google Mobile Ads SDK |
| **App Info & Performance** | Crash logs, diagnostics | **YES** | **YES** | SDK stability, error reporting, and latency diagnostics. | No | Google Mobile Ads SDK |

---

## 3. Data Safety Questionnaire Answers for Google Play Console

### Section: Data Collection and Security
1. **Does your app collect or share any of the required user data types?**
   - **YES** (Due to Google Mobile Ads SDK and Google Play Billing SDK).
2. **Is all of the user data collected by your app encrypted in transit?**
   - **YES** (All communications by Google Mobile Ads and Google Play Billing use TLS 1.3 / HTTPS).
3. **Do you provide a way for users to request that their data be deleted?**
   - **YES** (Users can reset their Advertising ID in Android Settings, clear app cache/history in FileWorks, and revoke consent via Settings > Ad & Privacy Choices. No user accounts exist).

### Section: Specific Data Types
1. **Device or other IDs -> Device or other IDs:**
   - **Collected:** Yes
   - **Shared:** Yes (Shared with Google AdMob)
   - **Processed ephemerally:** No
   - **Is this data required for your app, or can users choose whether it's collected?** Users cannot opt out if using the free ad-supported tier, but can upgrade to Premium to remove all ads, or manage consent in EEA/UK via UMP.
   - **Why is this user data collected?**
     - Advertising or marketing
     - Fraud prevention, security, and compliance
     - Analytics
2. **Financial info -> Purchase history:**
   - **Collected:** Yes
   - **Shared:** No
   - **Processed ephemerally:** No
   - **Is this data required?** Optional (Only collected if user purchases Premium).
   - **Why is this user data collected?**
     - App functionality (subscription entitlement unlocking)
     - Account management
3. **App info and performance -> Crash logs / Diagnostics:**
   - **Collected:** Yes
   - **Shared:** Yes (Shared with Google)
   - **Processed ephemerally:** No
   - **Why is this user data collected?**
     - Analytics
     - Fraud prevention, security, and compliance
4. **Location -> Approximate location:**
   - **Collected:** Yes
   - **Shared:** Yes (Processed by Google AdMob via IP address)
   - **Processed ephemerally:** Yes
   - **Why is this user data collected?**
     - Advertising or marketing
5. **Files & Docs -> Photos and videos / Files and docs:**
   - **Collected:** **NO**. User files are processed strictly on-device and are never uploaded to any server.

---

## 4. Key Highlights for Reviewers
- FileWorks is a **zero-cloud-upload** document utility.
- All PDF, Image, ZIP, and Rename processing is performed exclusively inside on-device Dart isolates.
- There are no FileWorks user accounts, no FileWorks database servers, and no third-party telemetry or analytics brokers (no Firebase Analytics, no Facebook SDK, no Sentry).

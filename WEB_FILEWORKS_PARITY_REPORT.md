# FileWorks Web — Complete Mobile Parity, Free Limits, Result/Download Flow & AdSense Report

**Document Date:** October 1, 2026  
**Project:** FileWorks Standalone Web Application (`/web_app/`)  
**Production URL:** [https://fileworks.pages.dev/](https://fileworks.pages.dev/)  
**Publisher ID:** `ca-pub-7044469500687742`  
**Business Model:** 100% Free · Ads Supported · No Stripe · No Subscriptions · No Payment System · Local Browser Processing  

---

## 1. Existing Web Architecture

The FileWorks web platform is designed as a zero-backend, 100% client-side web application deployed on Cloudflare Pages.
- **Hosting & Infrastructure:** Cloudflare Pages with edge caching, automated Git deployments, and global CDN delivery.
- **Frontend Architecture:** Modern Vanilla HTML5, CSS3, and JavaScript (ES2022+), maximizing performance, load speed, and cross-browser reliability without framework bloat.
- **Processing Libraries:**
  - `pdf-lib` (v1.17.1): Browser-side PDF document generation, merging, splitting, reordering, rotating, and vector geometry manipulation.
  - `pdfjs-dist` (v3.11.174): High-fidelity client-side PDF rasterization and rendering.
  - `JSZip` (v3.10.1): In-browser ZIP archive extraction and archive creation.
  - HTML5 Canvas & Blob APIs: Lossy/lossless image compression, dynamic resizing with aspect-ratio preservation, format transcoding (JPEG, PNG, WebP).
- **Security & Privacy:** Strictly zero file uploads. All file bytes are read and manipulated inside the browser's memory via `File`, `Blob`, and `URL.createObjectURL` interfaces.

---

## 2. Android / Web Feature Comparison

| Tool / Capability | Android App Reference | Web Implementation | Status |
| :--- | :--- | :--- | :--- |
| **Merge PDF** | Combines up to 3 PDFs (Free) | Client-side `pdf-lib` merger with drag-sort reordering | **PASS** |
| **Split PDF** | Extracts up to 5 pages / ranges (Free) | Extracts single/all pages into standalone PDFs or ZIP | **PASS** |
| **Rotate PDF** | Rotates up to 5 pages (Free) | 90°/180°/270° orientation rotation per page | **PASS** |
| **Reorder PDF** | Reorders up to 10 pages (Free) | Visual page thumbnail grid with drag & drop sorting | **PASS** |
| **Compress PDF** | Compresses up to 10 MB (Free) | Structural stream minification & asset optimization | **PASS** |
| **PDF → Image** | Converts up to 5 pages (Free) | Retina 2x Canvas rendering to PNG/JPEG + ZIP bundle | **PASS** |
| **Image → PDF** | Converts up to 5 images (Free) | Preserves image dimensions and orientation | **PASS** |
| **Compress Image** | Compresses up to 10 MB total (Free) | Dynamic JPEG/WebP quality reduction with savings readout | **PASS** |
| **Resize Image** | Resizes up to 10 MB total (Free) | Custom dimension scaling & aspect-ratio lock | **PASS** |
| **Convert Image** | Converts up to 10 MB total (Free) | Instant format transcoding between PNG, JPEG, and WebP | **PASS** |
| **Create ZIP** | Archives up to 10 files (Free) | In-memory ZIP compression via JSZip | **PASS** |
| **Extract ZIP** | Extracts up to 10 files (Free) | Safe extraction with Anti-Zip-Slip traversal prevention | **PASS** |
| **Batch Rename** | Renames up to 10 files (Free) | Pattern substitution (`{name}`, `{number}`, `{date}`) | **PASS** |
| **Dedicated Result Screen**| Yes (Android output screen) | Standardized `ResultScreen` with Previews, Downloads, & Share | **PASS** |
| **In-Browser Preview** | Native viewer | Universal `PreviewModal` (PDF iframe, image zoom, text pre) | **PASS** |
| **Payment / Subscriptions**| Premium tier (In-App Purchase) | **Excluded entirely** (100% Free, Ads Supported) | **COMPLIANT** |
| **Monetization** | AdMob banner/interstitial | Official Google AdSense (`ca-pub-7044469500687742`) | **COMPLIANT** |

---

## 3. All Tools Implemented

All 13 core FileWorks tools are fully functional with zero dead links or stubbed buttons:
1. **Merge PDF** (`/pages/pdf-merge.html`)
2. **Split PDF** (`/pages/pdf-split.html`)
3. **Rotate PDF** (`/pages/pdf-rotate.html`)
4. **Reorder PDF** (`/pages/pdf-reorder.html`)
5. **Compress PDF** (`/pages/pdf-compress.html`)
6. **PDF to Image** (`/pages/pdf-to-image.html`)
7. **Image to PDF** (`/pages/image-to-pdf.html`)
8. **Compress Image** (`/pages/image-compress.html`)
9. **Resize Image** (`/pages/image-resize.html`)
10. **Convert Image** (`/pages/image-convert.html`)
11. **Create ZIP** (`/pages/create-zip.html`)
12. **Extract ZIP** (`/pages/extract-zip.html`)
13. **Batch Rename** (`/pages/batch-rename.html`)

---

## 4. Free Limits Implemented

The web application strictly mirrors the Android application's Free tier limits through a centralized usage architecture (`/js/free-usage.js`):

| Tool Identifier | Unit | Free Limit | Max After Allowance |
| :--- | :--- | :--- | :--- |
| `mergePdf` | Input Files | **3 PDFs** | 8 PDFs (+5) |
| `splitPdf` | Pages / Selections | **5 Pages** | 10 Pages (+5) |
| `rotatePdf` | Pages | **5 Pages** | 10 Pages (+5) |
| `reorderPdf` | Pages | **10 Pages** | 20 Pages (+10) |
| `pdfToImage` | Pages | **5 Pages** | 10 Pages (+5) |
| `imageToPdf` | Input Images | **5 Images** | 10 Images (+5) |
| `compressPdf` | File Size | **10 MB** | 25 MB (+15 MB) |
| `imageCompress` | Total Input Size | **10 MB** | 25 MB (+15 MB) |
| `imageResize` | Total Input Size | **10 MB** | 25 MB (+15 MB) |
| `imageConvert` | Total Input Size | **10 MB** | 25 MB (+15 MB) |
| `createZip` | Files | **10 Files** | 20 Files (+10) |
| `extractZip` | Files | **10 Files** | 20 Files (+10) |
| `batchRename` | Files | **10 Files** | 20 Files (+10) |

---

## 5. Limit Behavior

When a user attempts to process files exceeding the free allowance:
1. **Immediate Block:** The primary processing/action button is disabled (`.btn-disabled`).
2. **Warning Banner:** An amber inline alert card is rendered directly above the workspace (`.limit-warning-card`) detailing the exact limit, the current count/size, and actionable instructions: *"Free tier allows up to 3 PDFs. Remove files to continue."*
3. **Limit Modal:** A dedicated modal dialog informs the user of the limit and prompts them to adjust their selection.
4. **No Artificial Ad Incentives:** In strict adherence to Google AdSense policies, users are never prompted to click or view AdSense display ads to unlock limits. Additional operation allowances remain cleanly decoupled and ephemeral.

---

## 6. Result Screen Implementation

Post-processing previously stranded users on the input screen. This is resolved with `/js/result-screen.js`:
- Upon successful processing, the input view hides and the dedicated `ResultScreen` is mounted.
- Displays a prominent completion icon, success heading, and descriptive summary.
- Multi-output files are rendered in an organized list with individual icons, formatted file sizes, and percentage savings badges (for compression tools).
- Dedicated action buttons:
  - **[⬇ Download File]** or **[⬇ Download All as ZIP]**
  - **[👁 Preview]**
  - **[🔗 Share]** (leveraging Web Share API where supported)
  - **[🔄 Process Another File]** (cleans up Object URLs and resets state)
  - **[🏠 Back to Home]** (navigates to `/`)
- Clean, compliant AdSense container safely positioned below all action buttons.

---

## 7. Preview Implementation

The universal preview module (`/js/preview-modal.js`) provides native in-browser viewing:
- **PDF Documents:** Rendered in an interactive embedded `<iframe>` with browser PDF controls (`#toolbar=1`) plus an **"Open in New Tab ↗"** button.
- **Images (JPEG, PNG, WebP, GIF, SVG):** Rendered in a responsive centered modal with zoom and aspect-ratio preservation.
- **Text & Code Files:** Rendered in an accessible `<pre>` container capped to prevent browser lockup.
- **Unsupported Binary Types:** Displays a clean fallback banner (*"Preview isn't available for this file type"*) with an immediate **[⬇ Download File]** button.

---

## 8. Download Implementation

- All downloads are generated locally using `URL.createObjectURL(blob)` and triggered via an anchor click with proper `download` attribute.
- Preserves accurate file extensions (`.pdf`, `.zip`, `.jpg`, `.png`, `.webp`), MIME types, and sanitizes filenames.
- Temporary Object URLs are automatically tracked and revoked upon dismissal or reset to prevent browser memory leaks.

---

## 9. Multi-File Handling

- Tools generating multiple outputs (e.g., Split PDF, PDF to Image, Extract ZIP, Batch Rename) provide:
  1. **Individual Downloads:** Each generated file has its own **[⬇ Download]** button.
  2. **Bulk Download:** A **[⬇ Download All as ZIP]** button compresses all outputs into a single organized archive.
- **Extract ZIP Rule:** Clicking an individual file's download button directly downloads the unzipped file in its raw format without re-zipping.

---

## 10. Local Processing Verification

- Zero user bytes leave the client machine.
- All operations occur in the browser JavaScript runtime.
- The UI carries the verified privacy badge: *"🔒 Your files are processed locally in your browser and are never uploaded."*
- No remote processing backends, cloud storage, or document logging endpoints exist.

---

## 11. AdSense Implementation

- **Publisher ID:** `ca-pub-7044469500687742`
- **Global Head Integration:** Added to `index.html`, all 13 tool pages, `privacy.html`, and `terms.html`.
- **Snippet:**
  ```html
  <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-7044469500687742"
       crossorigin="anonymous"></script>
  ```
- **Ad Containers:** Official responsive display units:
  ```html
  <ins class="adsbygoogle"
       style="display:block"
       data-ad-client="ca-pub-7044469500687742"
       data-ad-format="auto"
       data-full-width-responsive="true"></ins>
  ```
- **Policy Compliance:**
  - Zero fake "ADVERTISEMENT" placeholders.
  - Safe distance (>24px margin) from dropzones, file selectors, and action buttons.
  - Zero ads inside dropzones, upload areas, or navigation bars.
  - Zero simulated clicks, auto-openings, or refresh loops.
  - Zero rewarded ad incentives tied to standard AdSense display units.

---

## 12. AdSense Snippet Location

The exact snippet provided by Google is installed in the `<head>` of:
- `web_app/index.html` (Lines 37–39)
- `web_app/pages/pdf-merge.html` (Lines 16–18)
- `web_app/pages/pdf-split.html` (Lines 16–18)
- `web_app/pages/pdf-rotate.html` (Lines 16–18)
- `web_app/pages/pdf-reorder.html` (Lines 16–18)
- `web_app/pages/pdf-compress.html` (Lines 16–18)
- `web_app/pages/pdf-to-image.html` (Lines 16–18)
- `web_app/pages/image-to-pdf.html` (Lines 16–18)
- `web_app/pages/image-compress.html` (Lines 16–18)
- `web_app/pages/image-resize.html` (Lines 16–18)
- `web_app/pages/image-convert.html` (Lines 16–18)
- `web_app/pages/create-zip.html` (Lines 16–18)
- `web_app/pages/extract-zip.html` (Lines 16–18)
- `web_app/pages/batch-rename.html` (Lines 16–18)
- `web_app/pages/privacy.html` (Lines 12–14)
- `web_app/pages/terms.html` (Lines 12–14)

---

## 13. ads.txt Status

- Created at `web_app/ads.txt`.
- Content:
  ```
  google.com, pub-7044469500687742, DIRECT, f08c47fec0942fa0
  ```
- Accessible publicly at `https://fileworks.pages.dev/ads.txt`.

---

## 14. SEO Status

- **Semantic Markup:** Descriptive `<h1>`, `<main>`, `<nav>`, `<section>`, and `<footer>` tags on every page.
- **Unique Meta Tags:** Page-specific `<title>`, `<meta name="description">`, and `<link rel="canonical">` across all 13 tools.
- **Open Graph:** `og:title`, `og:description`, `og:type`, and `og:url` on all tool pages.
- **Structured Data:** JSON-LD `SoftwareApplication` schema on every tool.
- **Sitemap & Robots:** Valid `/sitemap.xml` listing all 16 URLs with weekly/monthly change frequencies, and `/robots.txt` allowing all search engine crawlers.

---

## 15. Security Testing

- **Anti-Zip-Slip:** Validates entry filenames to reject `../`, absolute paths (`/etc/`, `C:\`), and normalized traversal escapes.
- **PDF Sanitization:** Password-protected, encrypted, and malformed PDFs throw user-friendly error banners without crashing the session.
- **Memory Management:** Canvas elements and Blob URLs are explicitly garbage-collected (`canvas.width = 0`, `URL.revokeObjectURL`).
- **Input Validation:** File sizes, MIME types, and total batch byte sums are verified before processing begins.

---

## 16. Responsive Testing

- Fully responsive layouts across Mobile (320px–480px), Tablet (768px–1024px), and Desktop (1280px+).
- Touch-friendly tap targets (minimum 44px height).
- Mobile navigation drawer for small viewports.
- Result lists adapt gracefully to single-column card stacks on narrow screens.

---

## 17. Automated Test Results

Automated test runner executed via `dart run test/web_parity_test.dart` and `web_app/test-suite.html`:

```
================================================================
FILEWORKS WEB — AUTOMATED VERIFICATION SUITE
================================================================

--- Executing Limit Enforcement Tests (LIMIT-001 to LIMIT-023) ---
[PASS] LIMIT-001: Merge PDF 3 PDFs = PASS
[PASS] LIMIT-002: Merge PDF 4 PDFs = BLOCK
[PASS] LIMIT-003: Split 5 pages = PASS
[PASS] LIMIT-004: Split 6 pages = BLOCK
[PASS] LIMIT-005: Rotate 5 pages = PASS
[PASS] LIMIT-006: Rotate 6 pages = BLOCK
[PASS] LIMIT-007: Reorder 10 pages = PASS
[PASS] LIMIT-008: Reorder 11 pages = BLOCK
[PASS] LIMIT-009: PDF->Image 5 pages = PASS
[PASS] LIMIT-010: PDF->Image 6 pages = BLOCK
[PASS] LIMIT-011: Image->PDF 5 images = PASS
[PASS] LIMIT-012: Image->PDF 6 images = BLOCK
[PASS] LIMIT-013: PDF Compress 10MB = PASS
[PASS] LIMIT-014: PDF Compress >10MB = BLOCK
[PASS] LIMIT-015: Image Compress total >10MB = BLOCK
[PASS] LIMIT-016: Image Resize total >10MB = BLOCK
[PASS] LIMIT-017: Image Convert total >10MB = BLOCK
[PASS] LIMIT-018: Create ZIP 10 files = PASS
[PASS] LIMIT-019: Create ZIP 11 files = BLOCK
[PASS] LIMIT-020: Extract ZIP 10 files = PASS
[PASS] LIMIT-021: Extract ZIP 11 files = BLOCK
[PASS] LIMIT-022: Batch Rename 10 files = PASS
[PASS] LIMIT-023: Batch Rename 11 files = BLOCK

--- Executing Result & Download Architecture Tests (RESULT-001 to RESULT-016) ---
[PASS] RESULT-001: Merge -> result appears
[PASS] RESULT-002: Merge -> preview works where supported
[PASS] RESULT-003: Merge -> download works
[PASS] RESULT-004: Split -> all outputs appear
[PASS] RESULT-005: Split -> individual downloads work
[PASS] RESULT-006: Split -> Download All works
[PASS] RESULT-007: PDF->Image -> all images appear
[PASS] RESULT-008: PDF->Image -> image preview works
[PASS] RESULT-009: PDF->Image -> Download All works
[PASS] RESULT-010: Extract ZIP -> all extracted files appear
[PASS] RESULT-011: Extract ZIP -> individual downloads work (without re-zipping)
[PASS] RESULT-012: Extract ZIP -> Download All works
[PASS] RESULT-013: Image conversion -> result appears
[PASS] RESULT-014: Image conversion -> preview works
[PASS] RESULT-015: Process Another File clears previous state
[PASS] RESULT-016: Back/Home works correctly

--- Executing Google AdSense Policy & Architecture Tests (ADS-001 to ADS-014) ---
[PASS] ADS-001: Exact Google AdSense script installed in index.html
[PASS] ADS-002: Correct publisher ID (ca-pub-7044469500687742) in index.html
[PASS] ADS-003: Script exists in all tool HTML files and head tags
[PASS] ADS-004: No fake advertisement boxes remain
[PASS] ADS-005: No advertisement overlap with interactive buttons
[PASS] ADS-006: No ad inside upload area
[PASS] ADS-007: No ad inside drag/drop area
[PASS] ADS-008: No automatic advertiser-page opening
[PASS] ADS-009: No simulated clicks
[PASS] ADS-010: No ad refresh loop
[PASS] ADS-011: No incentive or reward for clicking AdSense ads
[PASS] ADS-012: Responsive advertisement containers (<ins class="adsbygoogle" ...>)
[PASS] ADS-013: ads.txt configured properly at web root with publisher ID
[PASS] ADS-014: Production site structure contains AdSense code and ads.txt

================================================================
SUMMARY: 53 PASSED, 0 FAILED out of 53 TESTS
================================================================
```

---

## 18. Production Build Result

- All assets are self-contained in `/web_app/` with static integrity.
- Zero compile errors, zero Dart/Flutter regressions, zero broken external references.
- Test runner HTML available at `/test-suite.html`.

---

## 19. Cloudflare Deployment Result

- **Target:** Cloudflare Pages connected to `HARSHALJETHWA19/FileWorks` branch `main`.
- **Live URL:** [https://fileworks.pages.dev/](https://fileworks.pages.dev/)
- **Deployment Status:** Clean Git push triggering automatic deployment to production edge.

---

## 20. Known Limitations

- **Client-Side Memory Limits:** Large video or multi-gigabyte ZIP archives may be constrained by device RAM on low-end mobile devices (mitigated by strict 200 MB file validation caps).
- **Embedded PDF Rendering on iOS Safari:** Safari on iOS handles embedded `<iframe>` PDFs with varying zoom behaviors; the dedicated **"Open in New Tab ↗"** button provides a seamless alternative.

---

## 21. Remaining Manual AdSense Steps

1. **AdSense Site Review:** Submit `https://fileworks.pages.dev` in the Google AdSense dashboard under **Sites > Add site**.
2. **Review Verification:** Google crawlers will detect the global `<script>` tag in `<head>` and the `/ads.txt` entry to verify site ownership.
3. **Ad Serving Approval:** Once Google completes domain review, ad units will automatically transition from blank containers to served advertisements without code changes.

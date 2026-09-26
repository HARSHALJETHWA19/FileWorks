# Google Play Store Graphic Assets Checklist: FileWorks

**Package Name:** `com.fileworks.app`  
**Auditor / Release Engineer:** Antigravity AI  
**Date:** September 26, 2026  

---

## 1. Store Icon (Required)

| Requirement | Specification | FileWorks Asset | Status |
| :--- | :--- | :--- | :---: |
| **Format** | 32-bit PNG (with alpha) | `assets/branding/fileworks_play_store_512.png` | **READY** |
| **Dimensions** | 512 px by 512 px | 512 x 512 pixels | **PASS** |
| **Max File Size** | 1,024 KB | 32,003 bytes (~31 KB) | **PASS** |
| **Design** | Clean brand mark on subtle gradient; no badges/stars | Official FileWorks precision brand icon | **PASS** |

Alternative monochrome/light variants available in `assets/branding/`:
- `app_icon_512.png` (Standard)
- `fileworks_icon_light_512.png` (Light variant)
- `fileworks_icon_monochrome_512.png` (Monochrome variant)

---

## 2. Feature Graphic (Required)

| Requirement | Specification | Instructions for Upload | Status |
| :--- | :--- | :--- | :---: |
| **Format** | JPEG or 24-bit PNG (no alpha) | Export from `assets/branding/fileworks_master_logo.svg` | **ACTION REQUIRED** |
| **Dimensions** | 1024 px width by 500 px height | Exactly 1024 x 500 px | Required for Play Store listing |
| **Max File Size** | 15 MB | Target ~200-500 KB PNG/JPEG | Safe |
| **Content** | FileWorks brand logo centered on brand gradient (#1976D2 to #0D47A1) with tagline "Simple. Private. Local." | Center important graphics within safe zone (avoid edges) | Ready to generate |

---

## 3. Phone Screenshots (Required)

Google Play requires a minimum of **2 screenshots**, with 4–8 recommended. Maximum 8 per device type. Minimum dimension: 320 px; maximum dimension: 3840 px.

The following real physical device screenshots from `qa_evidence/` are curated for immediate Play Store upload:

| Screenshot # | Source File in `qa_evidence/` | Content / Screen | Captions / Focus |
| :---: | :--- | :--- | :--- |
| **1** | `fileworks_home.png` | Home Dashboard | "All-in-one PDF, Image & File Utilities" |
| **2** | `merge_screen_files_loaded.png` | PDF Merge Screen | "Combine & Organize Multiple Documents" |
| **3** | `img_compress_config.png` | Image Compressor | "Optimize & Compress Photos without Quality Loss" |
| **4** | `zip_extract_result.png` | Extract ZIP Result | "Extract Archives & Save All Files Individually" |
| **5** | `open_file_result.png` | Operation Complete | "Instant Preview, System Share & Device Save" |
| **6** | `13_dark_mode.png` | Dark Theme UI | "Sleek Dark Mode & Modern Material 3 Design" |
| **7** | `settings_view.png` | Settings & Privacy | "Local-First Processing & Complete Privacy Choices" |
| **8** | `11_premium.png` | FileWorks Premium | "Optional Ad-Free Workflow with Unlimited Processing" |

---

## 4. Adaptive App Launcher Icons (In-App & System)

Verified in `android/app/src/main/res/`:
- `mipmap-anydpi-v26/ic_launcher.xml` (Adaptive icon with foreground vector and background color)
- `mipmap-anydpi-v26/ic_launcher_round.xml` (Adaptive round icon)
- Density rasters: `mipmap-hdpi`, `mipmap-mdpi`, `mipmap-xhdpi`, `mipmap-xxhdpi`, `mipmap-xxxhdpi`
- Status: **PASS** (Crisp vector/raster scaling across all Android device densities).

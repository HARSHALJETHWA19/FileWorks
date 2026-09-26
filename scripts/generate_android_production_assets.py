import os
from PIL import Image

# Import the generator function from generate_pure_logo
from generate_pure_logo import create_pure_fileworks_icon

def generate_all_production_assets():
    res_dir = "e:/FileKit/android/app/src/main/res"
    branding_dir = "e:/FileKit/assets/branding"
    os.makedirs(branding_dir, exist_ok=True)
    os.makedirs(f"{res_dir}/values", exist_ok=True)
    os.makedirs(f"{res_dir}/mipmap-anydpi-v26", exist_ok=True)

    # 1. Master High-Resolution Assets
    print("Generating Google Play Store Master (512x512)...")
    play_icon = create_pure_fileworks_icon(512, is_adaptive_foreground=False, background_mode="dark")
    play_icon.save(f"{branding_dir}/fileworks_play_store_512.png")
    
    print("Generating Light Theme Master (512x512)...")
    light_icon = create_pure_fileworks_icon(512, is_adaptive_foreground=False, background_mode="light")
    light_icon.save(f"{branding_dir}/fileworks_icon_light_512.png")

    print("Generating Monochrome Master (512x512)...")
    mono_icon = create_pure_fileworks_icon(512, is_adaptive_foreground=False, is_monochrome=True)
    mono_icon.save(f"{branding_dir}/fileworks_icon_monochrome_512.png")

    print("Generating In-App UI Brand Asset (192x192)...")
    in_app_icon = create_pure_fileworks_icon(192, is_adaptive_foreground=False, background_mode="dark")
    in_app_icon.save(f"{branding_dir}/app_icon_in_app.png")

    # 2. Android Adaptive Foreground Assets (108dp base canvas)
    # mdpi: 108x108, hdpi: 162x162, xhdpi: 216x216, xxhdpi: 324x324, xxxhdpi: 432x432
    density_map_fg = {
        "mipmap-mdpi": 108,
        "mipmap-hdpi": 162,
        "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324,
        "mipmap-xxxhdpi": 432,
    }

    for folder, size in density_map_fg.items():
        target_dir = f"{res_dir}/{folder}"
        os.makedirs(target_dir, exist_ok=True)
        print(f"Generating Adaptive Foreground {folder} ({size}x{size})...")
        fg = create_pure_fileworks_icon(size, is_adaptive_foreground=True)
        fg.save(f"{target_dir}/ic_launcher_foreground.png")

    # 3. Android Legacy Full Launcher Icons (48dp base canvas)
    # mdpi: 48x48, hdpi: 72x72, xhdpi: 96x96, xxhdpi: 144x144, xxxhdpi: 192x192
    density_map_legacy = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    for folder, size in density_map_legacy.items():
        target_dir = f"{res_dir}/{folder}"
        os.makedirs(target_dir, exist_ok=True)
        print(f"Generating Legacy Launcher Icon {folder} ({size}x{size})...")
        legacy = create_pure_fileworks_icon(size, is_adaptive_foreground=False, background_mode="dark")
        legacy.save(f"{target_dir}/ic_launcher.png")

    # 4. XML configurations for Android Adaptive Icon
    bg_xml_content = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0F172A</color>
</resources>
"""
    with open(f"{res_dir}/values/ic_launcher_background.xml", "w", encoding="utf-8") as f:
        f.write(bg_xml_content)

    adaptive_xml_content = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""
    with open(f"{res_dir}/mipmap-anydpi-v26/ic_launcher.xml", "w", encoding="utf-8") as f:
        f.write(adaptive_xml_content)

    with open(f"{res_dir}/mipmap-anydpi-v26/ic_launcher_round.xml", "w", encoding="utf-8") as f:
        f.write(adaptive_xml_content)

    print("All Android Production Assets & XML files successfully generated!")

if __name__ == "__main__":
    generate_all_production_assets()

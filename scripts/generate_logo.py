import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_master_logo(size=512, is_adaptive_foreground=False, is_monochrome=False):
    # Create high-res 4x supersampled image for ultra-smooth anti-aliasing
    scale = 4
    canvas_size = size * scale
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Coordinate mapping from base 512 to canvas_size
    def s(val):
        return val * scale * (size / 512.0)

    # 1. Background (only for non-adaptive launcher / store icons)
    if not is_adaptive_foreground:
        bg_radius = s(112)
        # Subtle dark slate / midnight navy background with refined depth
        # We draw a rounded squircle
        draw.rounded_rectangle(
            [(0, 0), (canvas_size, canvas_size)],
            radius=bg_radius,
            fill=(15, 23, 42, 255) # Slate 900 #0F172A
        )
        
        # Subtle ambient radial glow from top-center (modern subtle lighting)
        glow = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        glow_draw = ImageDraw.Draw(glow)
        glow_draw.ellipse(
            [(s(80), s(30)), (s(432), s(380))],
            fill=(37, 99, 235, 45) # Subtle royal blue bloom
        )
        glow = glow.filter(ImageFilter.GaussianBlur(radius=s(40)))
        img = Image.alpha_composite(img, glow)
        draw = ImageDraw.Draw(img)

    # Coordinates for the "Precision File F" symbol
    # Center of canvas is (256, 256)
    stem_left = s(142)
    stem_right = s(214)
    stem_top = s(122)
    stem_bottom = s(390)
    stem_r = s(20)

    top_arm_top = s(122)
    top_arm_bottom = s(194)
    top_arm_right = s(370)
    fold_inset = s(64) # 45 degree fold

    mid_arm_top = s(232)
    mid_arm_bottom = s(302)
    mid_arm_right = s(324)
    mid_arm_r = s(18)

    if is_monochrome:
        c_stem = (255, 255, 255, 255)
        c_top = (255, 255, 255, 255)
        c_fold = (255, 255, 255, 180) # Semi-translucent for monochrome fold
        c_fold_back = (0, 0, 0, 180) if is_adaptive_foreground else (15, 23, 42, 255)
        c_mid = (255, 255, 255, 255)
    else:
        # Full color palette:
        # Primary: Deep royal blue / electric sapphire #2563EB
        # Secondary: Indigo / Violet #6366F1 -> #7C3AED
        # Accent: Luminous lavender/violet #A5B4FC
        c_stem = (30, 64, 175, 255)      # Deep blue #1E40AF
        c_top = (37, 99, 235, 255)       # Royal blue #2563EB
        c_fold = (129, 140, 248, 255)    # Luminous periwinkle #818CF8
        c_fold_dark = (67, 56, 202, 255) # Under-fold shadow #4338CA
        c_mid = (124, 58, 237, 255)      # Electric Violet #7C3AED

    # LAYER 1: Vertical Stem (left vertical pillar)
    draw.rounded_rectangle(
        [(stem_left, stem_top), (stem_right, stem_bottom)],
        radius=stem_r,
        fill=c_stem
    )

    # LAYER 2: Top Arm (Document header with fold)
    # The body of top arm from stem to fold start
    # Draw polygon: (stem_left, stem_top) -> (top_arm_right - fold_inset, stem_top) ->
    # (top_arm_right, stem_top + fold_inset) -> (top_arm_right, top_arm_bottom) ->
    # (stem_left, top_arm_bottom)
    top_poly = [
        (stem_left + stem_r, top_arm_top),
        (top_arm_right - fold_inset, top_arm_top),
        (top_arm_right, top_arm_top + fold_inset),
        (top_arm_right, top_arm_bottom - s(12)),
        (top_arm_right - s(12), top_arm_bottom),
        (stem_left + stem_r, top_arm_bottom),
    ]
    draw.polygon(top_poly, fill=c_top)
    # Fill the top-left rounded connection
    draw.pieslice([(stem_left, top_arm_top), (stem_left + stem_r*2, top_arm_top + stem_r*2)], 180, 270, fill=c_top)

    # LAYER 3: The 45° Document Dog-Ear Fold
    # The folded corner geometry:
    # Corner cut background / under-fold shadow:
    under_fold_poly = [
        (top_arm_right - fold_inset, top_arm_top),
        (top_arm_right, top_arm_top),
        (top_arm_right, top_arm_top + fold_inset),
    ]
    # In full color, this area is the darker under-crease or background
    if not is_monochrome:
        # Underfold dark facet:
        fold_flap_poly = [
            (top_arm_right - fold_inset, top_arm_top),
            (top_arm_right - fold_inset, top_arm_top + fold_inset),
            (top_arm_right, top_arm_top + fold_inset),
        ]
        # Draw underfold shadow and folded flap
        draw.polygon(fold_flap_poly, fill=c_fold)
        # Fine highlight line on the diagonal crease
        draw.line([
            (top_arm_right - fold_inset, top_arm_top),
            (top_arm_right, top_arm_top + fold_inset)
        ], fill=(224, 231, 255, 200), width=int(s(2.5)))
    else:
        # For monochrome: folded flap is slightly separated or translucent
        fold_flap_poly = [
            (top_arm_right - fold_inset, top_arm_top),
            (top_arm_right - fold_inset, top_arm_top + fold_inset),
            (top_arm_right, top_arm_top + fold_inset),
        ]
        draw.polygon(fold_flap_poly, fill=c_fold)

    # LAYER 4: Middle Arm (Utility / Action leaf)
    # Extends from stem_right (or slightly overlapping stem) to mid_arm_right
    draw.rounded_rectangle(
        [(stem_right - s(10), mid_arm_top), (mid_arm_right, mid_arm_bottom)],
        radius=mid_arm_r,
        fill=c_mid
    )

    # Refined subtle gradient / accent on middle arm:
    # A sleek pill highlight on the middle arm
    if not is_monochrome:
        pill_left = stem_right + s(14)
        pill_right = mid_arm_right - s(14)
        pill_top = mid_arm_top + s(10)
        pill_bottom = mid_arm_bottom - s(10)
        draw.rounded_rectangle(
            [(pill_left, pill_top), (pill_right, pill_bottom)],
            radius=s(10),
            fill=(139, 92, 246, 160) # Violet 500 highlight
        )

    # Downsample cleanly to final target size with Lanczos filter
    final_img = img.resize((size, size), Image.Resampling.LANCZOS)
    return final_img

if __name__ == "__main__":
    os.makedirs("e:/FileKit/assets/branding", exist_ok=True)
    os.makedirs("e:/FileKit/qa_evidence", exist_ok=True)
    
    # 1. Master Play Store Icon 512x512
    master_512 = create_master_logo(512, is_adaptive_foreground=False)
    master_512.save("e:/FileKit/assets/branding/app_icon_512.png")
    
    # 2. Adaptive Foreground 432x432 (xxxhdpi)
    fg_432 = create_master_logo(432, is_adaptive_foreground=True)
    fg_432.save("e:/FileKit/assets/branding/ic_launcher_foreground.png")
    
    # 3. Monochrome Master 512x512
    mono_512 = create_master_logo(512, is_adaptive_foreground=False, is_monochrome=True)
    mono_512.save("e:/FileKit/assets/branding/app_icon_monochrome_512.png")
    
    # 4. Multi-size inspection sheet for QA verification
    sizes = [512, 192, 108, 72, 48, 32, 16]
    preview_strip = Image.new("RGBA", (1000, 560), (241, 245, 249, 255)) # Slate 100 bg
    pdraw = ImageDraw.Draw(preview_strip)
    pdraw.text((30, 20), "FileWorks Brand Icon - Multi-Density Visual Inspection", fill=(15, 23, 42, 255))
    
    # Place icons at various sizes
    curr_x = 30
    curr_y = 60
    # 512 (scaled down to 256 for sheet)
    p256 = master_512.resize((256, 256), Image.Resampling.LANCZOS)
    preview_strip.paste(p256, (curr_x, curr_y), p256)
    pdraw.text((curr_x, curr_y + 266), "512x512 (Master)", fill=(71, 85, 105, 255))
    
    curr_x += 290
    for s_val in [192, 108, 72, 48, 32, 16]:
        icon_s = create_master_logo(s_val, is_adaptive_foreground=False)
        preview_strip.paste(icon_s, (curr_x, curr_y), icon_s)
        pdraw.text((curr_x, curr_y + s_val + 8), f"{s_val}px", fill=(71, 85, 105, 255))
        curr_y += s_val + 34
        if curr_y > 440:
            curr_y = 60
            curr_x += 160
            
    preview_strip.save("e:/FileKit/qa_evidence/logo_multi_density_inspection.png")
    print("Logo assets generated successfully!")

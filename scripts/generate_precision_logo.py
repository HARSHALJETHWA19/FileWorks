import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_precision_fileworks_icon(
    size=512,
    is_adaptive_foreground=False,
    is_monochrome=False,
    background_mode="dark" # "dark", "light", "transparent"
):
    scale = 4
    canvas_size = size * scale
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    def s(val):
        return val * scale * (size / 512.0)

    # 1. Background
    if not is_adaptive_foreground:
        bg_radius = s(112)
        if background_mode == "dark":
            # Deep sleek obsidian / midnight navy
            draw.rounded_rectangle(
                [(0, 0), (canvas_size, canvas_size)],
                radius=bg_radius,
                fill=(15, 23, 42, 255) # Slate 900 #0F172A
            )
            # Subtle deep indigo ambient radial gradient
            glow = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
            g_draw = ImageDraw.Draw(glow)
            g_draw.ellipse(
                [(s(60), s(40)), (s(452), s(432))],
                fill=(37, 99, 235, 38) # Subtle #2563EB ambient depth
            )
            glow = glow.filter(ImageFilter.GaussianBlur(radius=s(48)))
            img = Image.alpha_composite(img, glow)
            draw = ImageDraw.Draw(img)
            
            # Ultra-subtle border stroke (1.5px) for crisp contrast on dark launcher
            border = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
            b_draw = ImageDraw.Draw(border)
            b_draw.rounded_rectangle(
                [(0, 0), (canvas_size - 1, canvas_size - 1)],
                radius=bg_radius,
                outline=(255, 255, 255, 25),
                width=int(s(2))
            )
            img = Image.alpha_composite(img, border)
            draw = ImageDraw.Draw(img)

        elif background_mode == "light":
            # Clean crisp white/slate background for light theme evaluation
            draw.rounded_rectangle(
                [(0, 0), (canvas_size, canvas_size)],
                radius=bg_radius,
                fill=(248, 250, 252, 255) # Slate 50
            )
            b_draw = ImageDraw.Draw(img)
            b_draw.rounded_rectangle(
                [(0, 0), (canvas_size - 1, canvas_size - 1)],
                radius=bg_radius,
                outline=(226, 232, 240, 255),
                width=int(s(2))
            )

    # Coordinates for the "Precision Fileworks F"
    # Canvas is 512x512. Center is (256, 256).
    # Safe zone: must fit well within 66dp (~310px) diameter when adaptive foreground.
    # Total icon bounds: x from 144 to 368 (width = 224), y from 124 to 388 (height = 264).
    # Center of glyph: x = 256, y = 256!
    # Distance from center to corners is sqrt(112^2 + 132^2) = 173px (< 180px safe circle).
    
    stem_x0 = s(144)
    stem_x1 = s(216) # width = 72
    glyph_y0 = s(124)
    glyph_y1 = s(388) # total height = 264
    
    top_x1 = s(368) # total width = 224
    top_y1 = s(204) # height = 80
    
    # Inward dog-ear fold coordinates:
    # Corner chamfer from (top_x1 - fold_size, glyph_y0) to (top_x1, glyph_y0 + fold_size)
    fold_size = s(62)
    fold_x0 = top_x1 - fold_size
    fold_y0 = glyph_y0
    fold_x1 = top_x1
    fold_y1 = glyph_y0 + fold_size

    mid_y0 = s(238)
    mid_y1 = s(308) # height = 70
    mid_x1 = s(326) # width from stem_x0 = 182 (shorter than top by ~42px, classic F proportion)

    r_outer = s(18)
    r_tip = s(16)

    # Color Palette definitions
    if is_monochrome:
        c_stem = (255, 255, 255, 255)
        c_top = (255, 255, 255, 255)
        c_fold_bg = (15, 23, 42, 255) if not is_adaptive_foreground else (0, 0, 0, 255)
        c_fold_flap = (255, 255, 255, 175)
        c_crease = (255, 255, 255, 120)
        c_mid = (255, 255, 255, 255)
        c_accent = (255, 255, 255, 210)
    else:
        # Full-Color Refined Palette:
        # Vertical Stem: Deep Indigo #1E40AF (primary anchor)
        c_stem = (30, 64, 175, 255)
        # Top Document Bar: Vivid Royal Blue #2563EB with subtle top highlight #3B82F6
        c_top = (37, 99, 235, 255)
        # Folded Flap (facing viewer): Luminous soft Indigo/Periwinkle #818CF8
        c_fold_flap = (129, 140, 248, 255)
        # Fold Crease highlight line: Crisp Ice White/Blue #E0E7FF
        c_crease = (224, 231, 255, 230)
        # Middle Utility Arm: Electric Violet/Purple #7C3AED
        c_mid = (124, 58, 237, 255)
        # Middle Arm Accent Glow / Pill indicator (representing local processing speed & organization)
        c_accent = (167, 139, 250, 255) # Violet 400 #A78BFA

    # LAYER 1: The Vertical Stem (Pillar)
    # Extends from glyph_y0 down to glyph_y1
    draw.rounded_rectangle(
        [(stem_x0, glyph_y0), (stem_x1, glyph_y1)],
        radius=r_outer,
        fill=c_stem
    )

    # LAYER 2: The Top Document Arm (with 45-degree inward corner chamfer)
    # Polygon vertices:
    # 1. (stem_x0 + r_outer, glyph_y0)
    # 2. (fold_x0, glyph_y0)
    # 3. (fold_x1, fold_y1)  <- 45 degree bevel!
    # 4. (fold_x1, top_y1 - r_tip)
    # 5. (fold_x1 - r_tip, top_y1)
    # 6. (stem_x1, top_y1)
    top_poly = [
        (stem_x0 + r_outer, glyph_y0),
        (fold_x0, glyph_y0),
        (fold_x1, fold_y1),
        (fold_x1, top_y1 - r_tip),
        (fold_x1 - r_tip, top_y1),
        (stem_x1, top_y1),
        (stem_x1, glyph_y0 + r_outer),
    ]
    draw.polygon(top_poly, fill=c_top)
    
    # Connect stem and top arm smoothly at top-left
    draw.pieslice([(stem_x0, glyph_y0), (stem_x0 + r_outer*2, glyph_y0 + r_outer*2)], 180, 270, fill=c_top)
    draw.rectangle([(stem_x0 + r_outer, glyph_y0), (stem_x1, glyph_y0 + r_outer)], fill=c_top)
    draw.rectangle([(stem_x0, glyph_y0 + r_outer), (stem_x1, top_y1)], fill=c_top)

    # LAYER 3: The Document Dog-Ear Inward Fold Flap
    # A true paper fold:
    # The flap folds inward from the crease line connecting (fold_x0, fold_y0) and (fold_x1, fold_y1).
    # When folded inward, the third corner lands at (fold_x0, fold_y1)!
    # Thus the folded flap triangle is: (fold_x0, fold_y0) -> (fold_x0, fold_y1) -> (fold_x1, fold_y1)!
    # Notice this creates an authentic, perfect 45-45-90 folded sheet corner!
    flap_poly = [
        (fold_x0, fold_y0),
        (fold_x0, fold_y1),
        (fold_x1, fold_y1),
    ]
    draw.polygon(flap_poly, fill=c_fold_flap)
    
    # Draw crisp diagonal crease line
    draw.line([(fold_x0, fold_y0), (fold_x1, fold_y1)], fill=c_crease, width=max(1, int(s(2.5))))

    # LAYER 4: The Middle Utility / Action Arm
    # Spans from stem_x1 to mid_x1, height from mid_y0 to mid_y1
    # Right cap has a refined curved radius
    mid_poly = [
        (stem_x1 - s(4), mid_y0),
        (mid_x1 - r_tip, mid_y0),
        (mid_x1, mid_y0 + r_tip),
        (mid_x1, mid_y1 - r_tip),
        (mid_x1 - r_tip, mid_y1),
        (stem_x1 - s(4), mid_y1),
    ]
    draw.polygon(mid_poly, fill=c_mid)
    # Smooth right cap
    draw.pieslice([(mid_x1 - r_tip*2, mid_y0), (mid_x1, mid_y0 + r_tip*2)], 270, 360, fill=c_mid)
    draw.pieslice([(mid_x1 - r_tip*2, mid_y1 - r_tip*2), (mid_x1, mid_y1)], 0, 90, fill=c_mid)
    draw.rectangle([(mid_x1 - r_tip, mid_y0), (mid_x1, mid_y1)], fill=c_mid)

    # LAYER 5: Sleek Micro-Detail on Middle Arm (Processing Indicator Notch)
    # A clean, minimal geometric horizontal pill line inside the middle arm
    # that communicates speed and transformation without looking cluttered.
    accent_y0 = mid_y0 + s(24)
    accent_y1 = mid_y1 - s(24)
    accent_x0 = stem_x1 + s(18)
    accent_x1 = mid_x1 - s(24)
    if accent_x1 > accent_x0:
        draw.rounded_rectangle(
            [(accent_x0, accent_y0), (accent_x1, accent_y1)],
            radius=s(8),
            fill=c_accent
        )

    # Downsample with high-grade Lanczos resampling
    final_img = img.resize((size, size), Image.Resampling.LANCZOS)
    return final_img

if __name__ == "__main__":
    os.makedirs("e:/FileKit/assets/branding", exist_ok=True)
    os.makedirs("e:/FileKit/qa_evidence", exist_ok=True)

    # 1. Google Play Store Master (512x512)
    play_icon = create_precision_fileworks_icon(512, is_adaptive_foreground=False, background_mode="dark")
    play_icon.save("e:/FileKit/assets/branding/fileworks_play_store_512.png")

    # 2. Adaptive Foreground (432x432 for xxxhdpi)
    adaptive_fg = create_precision_fileworks_icon(432, is_adaptive_foreground=True)
    adaptive_fg.save("e:/FileKit/assets/branding/ic_launcher_foreground.png")

    # 3. Light Theme Master (512x512)
    light_icon = create_precision_fileworks_icon(512, is_adaptive_foreground=False, background_mode="light")
    light_icon.save("e:/FileKit/assets/branding/fileworks_icon_light_512.png")

    # 4. Monochrome Master (512x512)
    mono_icon = create_precision_fileworks_icon(512, is_adaptive_foreground=False, is_monochrome=True)
    mono_icon.save("e:/FileKit/assets/branding/fileworks_icon_monochrome_512.png")

    # 5. Multi-Density QA Sheet
    qa_sheet = Image.new("RGBA", (1020, 580), (241, 245, 249, 255))
    q_draw = ImageDraw.Draw(qa_sheet)
    q_draw.text((30, 20), "FileWorks Precision Brand Icon - Multi-Density & Theme QA Inspection", fill=(15, 23, 42, 255))

    # Col 1: 512 Master Dark (scaled to 240)
    p240_dark = play_icon.resize((240, 240), Image.Resampling.LANCZOS)
    qa_sheet.paste(p240_dark, (30, 60), p240_dark)
    q_draw.text((30, 310), "512px Play Store Master (Dark)", fill=(71, 85, 105, 255))

    # Col 1 Bottom: 512 Master Light (scaled to 200)
    p200_light = light_icon.resize((200, 200), Image.Resampling.LANCZOS)
    qa_sheet.paste(p200_light, (30, 340), p200_light)
    q_draw.text((30, 548), "512px Light Mode Preview", fill=(71, 85, 105, 255))

    # Col 2: Multi-density inspection: 192, 144, 96, 72, 48, 32, 16
    curr_x = 310
    curr_y = 60
    for s_val in [192, 144, 96]:
        ic = create_precision_fileworks_icon(s_val, is_adaptive_foreground=False)
        qa_sheet.paste(ic, (curr_x, curr_y), ic)
        q_draw.text((curr_x + s_val + 16, curr_y + s_val // 2 - 6), f"{s_val} × {s_val} px (xxxhdpi/xxhdpi/xhdpi)", fill=(51, 65, 85, 255))
        curr_y += s_val + 24

    curr_x = 680
    curr_y = 60
    for s_val in [72, 48, 32, 16]:
        ic = create_precision_fileworks_icon(s_val, is_adaptive_foreground=False)
        qa_sheet.paste(ic, (curr_x, curr_y), ic)
        q_draw.text((curr_x + 90, curr_y + s_val // 2 - 6), f"{s_val} × {s_val} px (hdpi/mdpi/micro)", fill=(51, 65, 85, 255))
        curr_y += max(s_val + 28, 48)

    # Also show adaptive mask preview (Circular mask on 108dp)
    mask_preview = Image.new("RGBA", (140, 140), (0, 0, 0, 0))
    m_draw = ImageDraw.Draw(mask_preview)
    # Circle background
    m_draw.ellipse([(0, 0), (139, 139)], fill=(15, 23, 42, 255))
    # Paste scaled foreground
    fg_scaled = adaptive_fg.resize((140, 140), Image.Resampling.LANCZOS)
    mask_preview = Image.alpha_composite(mask_preview, fg_scaled)
    qa_sheet.paste(mask_preview, (curr_x, 340), mask_preview)
    q_draw.text((curr_x + 150, 390), "Adaptive Icon (Circle Mask 108dp)", fill=(15, 23, 42, 255))

    qa_sheet.save("e:/FileKit/qa_evidence/fileworks_icon_qa_validation.png")
    print("New Precision FileWorks Logo rendered successfully!")

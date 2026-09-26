import os
from PIL import Image, ImageDraw, ImageFilter

def create_pure_fileworks_icon(
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
            # Deep sleek midnight navy / obsidian #0F172A
            draw.rounded_rectangle(
                [(0, 0), (canvas_size, canvas_size)],
                radius=bg_radius,
                fill=(15, 23, 42, 255) # Slate 900 #0F172A
            )
            # Subtle deep royal-indigo ambient lighting
            glow = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
            g_draw = ImageDraw.Draw(glow)
            g_draw.ellipse(
                [(s(70), s(50)), (s(442), s(422))],
                fill=(37, 99, 235, 36) # Subtle #2563EB glow
            )
            glow = glow.filter(ImageFilter.GaussianBlur(radius=s(48)))
            img = Image.alpha_composite(img, glow)
            draw = ImageDraw.Draw(img)
            
            # Subtle 1.5px rim border for contrast against pitch-black wallpapers
            border = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
            b_draw = ImageDraw.Draw(border)
            b_draw.rounded_rectangle(
                [(0, 0), (canvas_size - 1, canvas_size - 1)],
                radius=bg_radius,
                outline=(255, 255, 255, 22),
                width=int(s(2))
            )
            img = Image.alpha_composite(img, border)
            draw = ImageDraw.Draw(img)

        elif background_mode == "light":
            draw.rounded_rectangle(
                [(0, 0), (canvas_size, canvas_size)],
                radius=bg_radius,
                fill=(248, 250, 252, 255) # Slate 50
            )
            b_draw = ImageDraw.Draw(img)
            b_draw.rounded_rectangle(
                [(0, 0), (canvas_size - 1, canvas_size - 1)],
                radius=bg_radius,
                outline=(203, 213, 225, 255),
                width=int(s(2))
            )

    # Balanced Geometric Proportions:
    # Canvas: 512x512. Center: (256, 256).
    # Stem: x: 140 -> 218 (width = 78)
    # Glyph bounds: y: 122 -> 390 (height = 268)
    # Top Arm: x: 140 -> 372 (width = 232), y: 122 -> 206 (height = 84)
    # Fold Size: 66px 45-degree inward cut
    # Middle Arm: x: 218 -> 330 (width = 112 from stem, total 190 from left), y: 242 -> 314 (height = 72)
    # Corner Radii: Clean, human designer precision
    
    stem_x0 = s(140)
    stem_x1 = s(218)
    glyph_y0 = s(122)
    glyph_y1 = s(390)
    
    top_x1 = s(372)
    top_y1 = s(206)
    
    fold_size = s(66)
    fold_x0 = top_x1 - fold_size
    fold_y0 = glyph_y0
    fold_x1 = top_x1
    fold_y1 = glyph_y0 + fold_size

    mid_y0 = s(244)
    mid_y1 = s(316)
    mid_x1 = s(332)

    r_stem = s(18)
    r_arm = s(16)

    # Color Palette:
    if is_monochrome:
        c_stem = (255, 255, 255, 255)
        c_top = (255, 255, 255, 255)
        c_fold_flap = (255, 255, 255, 175)
        c_crease = (255, 255, 255, 120)
        c_mid = (255, 255, 255, 255)
    else:
        # Master Production Colors:
        # Vertical Anchor Spine: Deep Royal Indigo #1E40AF
        c_stem = (30, 64, 175, 255)
        # Top Document Sheet: Bright Electric Sapphire #2563EB
        c_top = (37, 99, 235, 255)
        # Inward Fold Flap: Soft Luminous Periwinkle #818CF8
        c_fold_flap = (129, 140, 248, 255)
        # Precision Crease Line: Crisp Ice White #EEF2FF
        c_crease = (238, 242, 255, 240)
        # Middle Utility Arm: Vivid Electric Violet #7C3AED
        c_mid = (124, 58, 237, 255)

    # LAYER 1: The Vertical Stem (Anchor Spine)
    # Extends from glyph_y0 to glyph_y1 with rounded bottom
    draw.rounded_rectangle(
        [(stem_x0, glyph_y0), (stem_x1, glyph_y1)],
        radius=r_stem,
        fill=c_stem
    )

    # LAYER 2: The Top Document Arm (with precision 45-degree dog-ear chamfer)
    top_poly = [
        (stem_x0 + r_stem, glyph_y0),
        (fold_x0, glyph_y0),
        (fold_x1, fold_y1),
        (fold_x1, top_y1 - r_arm),
        (fold_x1 - r_arm, top_y1),
        (stem_x1, top_y1),
        (stem_x1, glyph_y0 + r_stem),
    ]
    draw.polygon(top_poly, fill=c_top)
    # Connect stem and top arm smoothly at top-left
    draw.pieslice([(stem_x0, glyph_y0), (stem_x0 + r_stem*2, glyph_y0 + r_stem*2)], 180, 270, fill=c_top)
    draw.rectangle([(stem_x0 + r_stem, glyph_y0), (stem_x1, glyph_y0 + r_stem)], fill=c_top)
    draw.rectangle([(stem_x0, glyph_y0 + r_stem), (stem_x1, top_y1)], fill=c_top)

    # LAYER 3: The True Document Inward Fold Flap
    # Triangular flap folding inward across the crease:
    flap_poly = [
        (fold_x0, fold_y0),
        (fold_x0, fold_y1),
        (fold_x1, fold_y1),
    ]
    draw.polygon(flap_poly, fill=c_fold_flap)
    # Fine crease line
    draw.line([(fold_x0, fold_y0), (fold_x1, fold_y1)], fill=c_crease, width=max(1, int(s(2.5))))

    # LAYER 4: The Middle Utility / Action Arm
    # Solid, authoritative, clean geometric bar
    draw.rounded_rectangle(
        [(stem_x1 - s(4), mid_y0), (mid_x1, mid_y1)],
        radius=r_arm,
        fill=c_mid
    )

    # Downsample with Lanczos filter for razor-sharp edge anti-aliasing
    final_img = img.resize((size, size), Image.Resampling.LANCZOS)
    return final_img

if __name__ == "__main__":
    os.makedirs("e:/FileKit/assets/branding", exist_ok=True)
    os.makedirs("e:/FileKit/qa_evidence", exist_ok=True)

    # 1. Master Play Store Icon 512x512
    play_icon = create_pure_fileworks_icon(512, is_adaptive_foreground=False, background_mode="dark")
    play_icon.save("e:/FileKit/assets/branding/fileworks_play_store_512.png")

    # 2. Adaptive Foreground 432x432 (xxxhdpi)
    adaptive_fg = create_pure_fileworks_icon(432, is_adaptive_foreground=True)
    adaptive_fg.save("e:/FileKit/assets/branding/ic_launcher_foreground.png")

    # 3. Light Theme Master 512x512
    light_icon = create_pure_fileworks_icon(512, is_adaptive_foreground=False, background_mode="light")
    light_icon.save("e:/FileKit/assets/branding/fileworks_icon_light_512.png")

    # 4. Monochrome Master 512x512
    mono_icon = create_pure_fileworks_icon(512, is_adaptive_foreground=False, is_monochrome=True)
    mono_icon.save("e:/FileKit/assets/branding/fileworks_icon_monochrome_512.png")

    # 5. Multi-Density QA Sheet
    qa_sheet = Image.new("RGBA", (1020, 580), (241, 245, 249, 255))
    q_draw = ImageDraw.Draw(qa_sheet)
    q_draw.text((30, 20), "FileWorks Pure Brand Icon - Multi-Density & Theme QA Inspection", fill=(15, 23, 42, 255))

    p240_dark = play_icon.resize((240, 240), Image.Resampling.LANCZOS)
    qa_sheet.paste(p240_dark, (30, 60), p240_dark)
    q_draw.text((30, 310), "512px Play Store Master (Dark)", fill=(71, 85, 105, 255))

    p200_light = light_icon.resize((200, 200), Image.Resampling.LANCZOS)
    qa_sheet.paste(p200_light, (30, 340), p200_light)
    q_draw.text((30, 548), "512px Light Mode Preview", fill=(71, 85, 105, 255))

    curr_x = 310
    curr_y = 60
    for s_val in [192, 144, 96]:
        ic = create_pure_fileworks_icon(s_val, is_adaptive_foreground=False)
        qa_sheet.paste(ic, (curr_x, curr_y), ic)
        q_draw.text((curr_x + s_val + 16, curr_y + s_val // 2 - 6), f"{s_val} × {s_val} px (xxxhdpi/xxhdpi/xhdpi)", fill=(51, 65, 85, 255))
        curr_y += s_val + 24

    curr_x = 680
    curr_y = 60
    for s_val in [72, 48, 32, 16]:
        ic = create_pure_fileworks_icon(s_val, is_adaptive_foreground=False)
        qa_sheet.paste(ic, (curr_x, curr_y), ic)
        q_draw.text((curr_x + 90, curr_y + s_val // 2 - 6), f"{s_val} × {s_val} px (hdpi/mdpi/micro)", fill=(51, 65, 85, 255))
        curr_y += max(s_val + 28, 48)

    # Adaptive circle mask preview (140x140)
    mask_preview = Image.new("RGBA", (140, 140), (0, 0, 0, 0))
    m_draw = ImageDraw.Draw(mask_preview)
    m_draw.ellipse([(0, 0), (139, 139)], fill=(15, 23, 42, 255))
    fg_scaled = adaptive_fg.resize((140, 140), Image.Resampling.LANCZOS)
    mask_preview = Image.alpha_composite(mask_preview, fg_scaled)
    qa_sheet.paste(mask_preview, (curr_x, 340), mask_preview)
    q_draw.text((curr_x + 150, 390), "Adaptive Icon (Circle Mask 108dp)", fill=(15, 23, 42, 255))

    qa_sheet.save("e:/FileKit/qa_evidence/fileworks_pure_icon_qa.png")
    print("Pure FileWorks Logo rendered successfully!")

import json
from PIL import Image, ImageDraw, ImageFont

ROWS = [
    ("Природа", [("grass_deep","#3E5A3A"),("grass_mid","#56724A"),("grass_light","#7A8F5C"),("hedge","#2F4A33"),
                 ("moss","#6B7A45"),("hay","#B9A46A"),("wheat","#D2BE84"),("dead_leaf","#8A6A3E")]),
    ("Земля и камень", [("mud_dark","#3F3329"),("mud","#5E4B3A"),("path_dirt","#7D6650"),("gravel","#8C877C"),
                 ("cotswold","#C9B27E"),("cotswold_shadow","#9E8758"),("slate","#4A4F57"),("flint","#6E7178")]),
    ("Постройки", [("brick","#8A4A3A"),("brick_dark","#6A372C"),("roof_slate","#3B3F47"),("plaster","#D8CFBE"),
                 ("timber","#4A3A2C"),("oak","#7A5A3A"),("door_green","#2E4A3E"),("window_frame","#E6E0D2")]),
    ("Индустрия", [("container_rust","#8C3B2E"),("container_red","#A14A35"),("container_green","#3F5B4A"),("corrugated","#7C8288"),
                 ("steel","#9AA0A6"),("steel_dark","#4C5157"),("rust","#7A4A2A"),("hazard_yellow","#C9A23A")]),
    ("Одежда", [("tweed_brown","#6B5640"),("tweed_green","#5A5F44"),("navy_suit","#2C3446"),("charcoal","#3A3A3D"),
                 ("camel_coat","#A88A62"),("shirt_cream","#E9E2D0"),("cap_grey","#6A6660"),("tie_burgundy","#6E2B33")]),
    ("Кожа и волосы", [("skin_1","#F1D2B6"),("skin_2","#E0B08C"),("skin_3","#C68B63"),("skin_4","#9C6644"),
                 ("skin_5","#6E452E"),("skin_6","#4A2E20"),("hair_dark","#2A2420"),("hair_fair","#B8955E")]),
    ("Подземелье", [("concrete","#6F6E6A"),("concrete_dark","#4A4946"),("soil","#3A2C22"),("plant_young","#7FA35A"),
                 ("plant_mid","#5A8A45"),("plant_ripe","#3F6E3A"),("pot_black","#26272A"),("lamp_warm","#F2C46B")]),
    ("Акценты", [("brass","#B08D4A"),("money_green","#6E8F5E"),("police_blue","#2F5D9E"),("alert_red","#B83A32"),
                 ("black","#1C1C1E"),("dark_grey","#3A3A3C"),("light_grey","#B5B5B0"),("white","#EDEBE6")]),
]
EMISSIVE = {"lamp_warm", "police_blue", "alert_red"}

CELL, N = 32, 8
SIZE = CELL * N
atlas = Image.new("RGB", (SIZE, SIZE))
d = ImageDraw.Draw(atlas)
swatches = {}
for r, (_, row) in enumerate(ROWS):
    for c, (name, hexv) in enumerate(row):
        x0, y0 = c * CELL, r * CELL
        d.rectangle([x0, y0, x0 + CELL - 1, y0 + CELL - 1], fill=hexv)
        swatches[name] = {
            "hex": hexv,
            "row": r, "col": c,
            "uv": [round((x0 + CELL / 2) / SIZE, 6), round((y0 + CELL / 2) / SIZE, 6)],
            "emissive": name in EMISSIVE,
        }
atlas.save("./palette_atlas.png")

meta = {
    "texture": "res://assets/textures/palette_atlas.png",
    "size_px": SIZE, "cell_px": CELL,
    "uv_rule": "Put every UV of a face at the swatch centre 'uv'. Godot/Blender: v measured from top (flip to 1-v in Blender).",
    "groups": [g for g, _ in ROWS],
    "swatches": swatches,
}
json.dump(meta, open("./palette.json", "w"), ensure_ascii=False, indent=2)

# labelled reference sheet
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
bold = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 17)
title = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf", 30)
small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 13)
SW, SH, GAP, LEFT, TOP = 150, 92, 10, 210, 100
W = LEFT + N * (SW + GAP) + 30
H = TOP + len(ROWS) * (SH + 44) + 20
ref = Image.new("RGB", (W, H), "#EFEBE3")
rd = ImageDraw.Draw(ref)
rd.text((30, 28), "Old Money — палитра мира (атлас 256×256, 64 цвета)", font=title, fill="#2A2420")
for r, (group, row) in enumerate(ROWS):
    y = TOP + r * (SH + 44)
    rd.text((30, y + SH // 2 - 10), group, font=bold, fill="#2A2420")
    for c, (name, hexv) in enumerate(row):
        x = LEFT + c * (SW + GAP)
        rd.rounded_rectangle([x, y, x + SW, y + SH], radius=8, fill=hexv, outline="#00000022")
        if name in EMISSIVE:
            rd.text((x + 8, y + 6), "светится", font=small, fill="#FFFFFF" if name != "lamp_warm" else "#2A2420")
        rd.text((x, y + SH + 4), name, font=font, fill="#2A2420")
        rd.text((x, y + SH + 22), hexv, font=small, fill="#6A6660")
ref.save("./palette_reference.png")
print("ok", len(swatches))

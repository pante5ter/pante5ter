"""Old Money: underground plantation models (raised bed, plant stages 1-4, grow lamp, duct, wall, lift cage).

Run headless from the repo root:
    "D:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python tools/blender/make_plantation.py

Output: assets/models/plantation/*.glb and tools/blender/previews/plantation.png. Front of every model = Godot +Z.
"""

import math
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import om_common as om  # noqa: E402

OUT = os.path.join(om.MODELS, "plantation")

BED_SOIL_TOP = 0.30


# ---------------------------------------------------------------- raised bed 2.3 x 1.5 x 0.35
def make_raised_bed(p: om.Palette):
    """Plank frame in the root; the soil surface is the child `Soil` (top at 0.30 m) so it can be swapped or
    darkened when watered. Plants stand on the soil top."""
    m = om.Mesh(p, "raised_bed")
    w, d, h, t = 2.3, 1.5, 0.35, 0.05
    for k, z in enumerate((0.0, 0.175)):
        col = "oak" if k == 0 else "dead_leaf"
        for side in (-1, 1):
            m.box_base((w - 0.12, t, 0.17), (0, side * (d / 2 - t / 2), z), col)
            m.box_base((t, d - 0.12, 0.17), (side * (w / 2 - t / 2), 0, z), col)
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box_base((0.09, 0.09, h + 0.03), (sx * (w / 2 - 0.045), sy * (d / 2 - 0.045), 0), "timber")
    # Top rail you can sit on, slightly proud of the planks.
    for side in (-1, 1):
        m.box_base((w - 0.18, 0.09, 0.03), (0, side * (d / 2 - 0.035), h - 0.01), "oak")
        m.box_base((0.09, d - 0.18, 0.03), (side * (w / 2 - 0.035), 0, h - 0.01), "oak")
    m.box_base((w - 0.1, d - 0.1, 0.02), (0, 0, 0.0), "soil")
    root = m.finish()
    s = om.Mesh(p, "Soil")
    s.box_base((w - 2 * t, d - 2 * t, BED_SOIL_TOP - 0.02), (0, 0, 0.02), {"all": "soil", "top": "soil"})
    for y in (-0.42, 0.0, 0.42):
        s.box_base((w - 0.3, 0.12, 0.012), (0, y, BED_SOIL_TOP), "mud_dark")
    s.finish(parent=root)
    return root


# ---------------------------------------------------------------- plants, 30-150 tris per stage
def _stem(m: om.Mesh, height: float, r0: float, color: str) -> None:
    m.tube((0, 0, 0), (0, 0, height), r0, r0 * 0.5, color=color, seg=4, caps=False, phase=45)


def make_plant_1(p: om.Palette):
    """Seedling, ~0.12 m: a stem, two seed leaves and a first true-leaf star."""
    m = om.Mesh(p, "plant_stage_1")
    _stem(m, 0.1, 0.012, "plant_young")
    m.leaf_star((0, 0, 0.07), 0.06, points=2, lift=0.01, droop=0.015, inner=0.3, color="plant_young")
    m.leaf_star((0, 0, 0.1), 0.045, points=4, lift=0.015, droop=0.01, inner=0.3, twist=45, color="plant_mid")
    return m.finish()


def make_plant_2(p: om.Palette):
    """Young plant, ~0.38 m."""
    m = om.Mesh(p, "plant_stage_2")
    _stem(m, 0.36, 0.02, "plant_mid")
    m.leaf_star((0, 0, 0.12), 0.16, points=5, lift=0.03, droop=0.05, color="plant_young")
    m.leaf_star((0, 0, 0.25), 0.12, points=5, lift=0.03, droop=0.04, twist=36, color="plant_young")
    m.leaf_star((0, 0, 0.35), 0.06, points=3, lift=0.03, droop=0.015, twist=15, color="plant_mid")
    return m.finish()


def make_plant_3(p: om.Palette):
    """Vegetative bush, ~0.8 m."""
    m = om.Mesh(p, "plant_stage_3")
    _stem(m, 0.78, 0.03, "plant_ripe")
    tiers = ((0.18, 0.3, 7, 0, "plant_ripe"), (0.36, 0.26, 7, 25, "plant_mid"),
             (0.54, 0.2, 6, 10, "plant_mid"), (0.7, 0.12, 5, 40, "plant_young"))
    for z, r, n, tw, col in tiers:
        m.leaf_star((0, 0, z), r, points=n, lift=0.05, droop=r * 0.3, twist=tw, color=col)
    return m.finish()


def make_plant_4(p: om.Palette):
    """Flowering plant, ~1.05 m, hay/wheat buds at the top and on the upper tiers."""
    m = om.Mesh(p, "plant_stage_4")
    _stem(m, 0.9, 0.035, "plant_ripe")
    tiers = ((0.22, 0.32, 6, 0), (0.46, 0.27, 6, 30), (0.68, 0.19, 5, 12))
    for z, r, n, tw in tiers:
        m.leaf_star((0, 0, z), r, points=n, lift=0.05, droop=r * 0.3, twist=tw, color="plant_ripe")
    # Top cola: two stacked buds; side buds sit on the leaf tiers close to the stem.
    m.bud((0, 0, 0.78), 0.075, 0.22, "wheat", seg=4, twist=45)
    m.bud((0, 0, 0.92), 0.055, 0.17, "hay", seg=4)
    for i, (r, z) in enumerate(((0.09, 0.5), (0.08, 0.72), (0.1, 0.27))):
        a = math.radians(40 + i * 125)
        m.bud((r * math.cos(a), r * math.sin(a), z), 0.05, 0.15, "hay" if i != 1 else "wheat", seg=4, twist=i * 20)
    return m.finish()


# ---------------------------------------------------------------- lighting and services
def make_grow_lamp(p: om.Palette):
    """1.2 m industrial lamp bar. Origin at the bottom of the light (hang it at the wanted height); the rods
    reach 0.7 m up to ceiling plates. The lamp_warm strip is on the emissive material."""
    m = om.Mesh(p, "grow_lamp")
    L = 1.2
    housing = [(-0.15, 0.015), (0.15, 0.015), (0.11, 0.1), (-0.11, 0.1)]
    along_x = om.Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    m.prism(housing, -L / 2, L, {"all": "steel_dark", "top": "dark_grey"}, along_x)
    m.box_base((L - 0.06, 0.24, 0.015), (0, 0, 0.0), "lamp_warm")
    for sx in (-1, 1):
        m.box_base((0.03, 0.32, 0.11), (sx * (L / 2 + 0.015), 0, 0.0), "black")
        m.tube((sx * 0.45, 0, 0.1), (sx * 0.45, 0, 0.8), 0.008, color="steel", seg=4, caps=False)
        m.box_base((0.12, 0.12, 0.015), (sx * 0.45, 0, 0.8), "steel_dark")
    m.box_base((0.16, 0.08, 0.05), (0.2, 0, 0.1), "black")  # driver box
    m.tube((0.28, 0, 0.12), (0.4, 0.02, 0.8), 0.006, color="black", seg=4, caps=False)
    return m.finish()


def make_vent_duct(p: om.Palette):
    """2 m rectangular duct along local X, 0.5 x 0.4, flanged ends that butt together; origin at the bottom."""
    m = om.Mesh(p, "vent_duct_2m")
    L, w, h = 2.0, 0.5, 0.4
    m.box_base((L - 0.08, w, h), (0, 0, 0.0), {"all": "steel", "bottom": "corrugated"})
    for sx in (-1, 1):
        m.box_base((0.04, w + 0.08, h + 0.08), (sx * (L / 2 - 0.02), 0, -0.04), "steel_dark")
    m.box_base((0.03, w + 0.02, h + 0.02), (0, 0, -0.01), "corrugated")
    # Supply grille on the front face.
    m.box((0.5, 0.012, 0.22), (-0.5, -w / 2 - 0.006, h / 2), "dark_grey")
    for z in (-0.06, 0.0, 0.06):
        m.box((0.46, 0.02, 0.02), (-0.5, -w / 2 - 0.012, h / 2 + z), "steel_dark")
    # Hanger straps up to the ceiling.
    for x in (-0.55, 0.55):
        for sy in (-1, 1):
            m.box_base((0.04, 0.01, h + 0.35), (x, sy * (w / 2 + 0.005), 0.0), "steel_dark")
        m.box_base((0.04, w + 0.02, 0.01), (x, 0, -0.01), "steel_dark")
    return m.finish()


def make_concrete_wall(p: om.Palette):
    """2 m wall segment along local X, 3 m high, 0.25 m thick; front face = Godot +Z. Ends butt together."""
    m = om.Mesh(p, "concrete_wall_2m")
    L, t, h = 2.0, 0.25, 3.0
    m.box_base((L, t, h), (0, 0, 0), {"all": "concrete", "top": "concrete_dark"})
    m.box_base((L, t + 0.04, 0.22), (0, 0, 0), "concrete_dark")
    m.box((L, 0.01, 0.03), (0, -t / 2 - 0.004, 1.6), "concrete_dark")
    for x in (-0.5, 0.5):
        for z in (0.8, 2.3):
            m.box((0.05, 0.01, 0.05), (x, -t / 2 - 0.004, z), "black")
    # Conduit and a junction box along the top, continuous across segments.
    m.tube((-L / 2, -t / 2 - 0.05, 2.65), (L / 2, -t / 2 - 0.05, 2.65), 0.025, color="steel_dark", seg=6, caps=False)
    m.box((0.14, 0.06, 0.14), (0.35, -t / 2 - 0.04, 2.65), "steel_dark")
    for x in (-0.7, 0.0, 0.7):
        m.box((0.03, 0.06, 0.06), (x, -t / 2 - 0.03, 2.65), "steel")
    return m.finish()


# ---------------------------------------------------------------- lift cage
CAGE = 2.0
CAGE_H = 2.5
FLOOR_T = 0.12


def make_lift_cage(p: om.Palette):
    """2 x 2 m goods lift. Open front (-Y in Blender, Godot +Z) is closed by the child `Door`: a lattice gate
    whose origin is its left bottom corner, so the game can slide it along local X or swing it about local Y."""
    m = om.Mesh(p, "lift_cage")
    half = CAGE / 2
    m.box_base((CAGE, CAGE, FLOOR_T), (0, 0, 0), {"all": "steel_dark", "top": "concrete_dark"})
    # Hazard stripes on the threshold.
    for i in range(8):
        col = "hazard_yellow" if i % 2 == 0 else "black"
        m.box_base((CAGE / 8, 0.14, 0.006), (-half + CAGE / 16 + i * CAGE / 8, -half + 0.07, FLOOR_T), col)
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box_base((0.08, 0.08, CAGE_H), (sx * (half - 0.04), sy * (half - 0.04), 0), "steel_dark")
    top = CAGE_H
    for sy in (-1, 1):
        m.box_base((CAGE, 0.08, 0.08), (0, sy * (half - 0.04), top - 0.08), "steel_dark")
    for sx in (-1, 1):
        m.box_base((0.08, CAGE, 0.08), (sx * (half - 0.04), 0, top - 0.08), "steel_dark")
    m.box_base((CAGE - 0.1, 0.1, 0.06), (0, 0, top - 0.06), "steel_dark")
    # Bar walls on the back and both sides, with mid rails.
    bars = 9
    for i in range(bars):
        f = -half + 0.08 + (CAGE - 0.16) * (i + 0.5) / bars
        m.tube((f, half - 0.04, FLOOR_T), (f, half - 0.04, top - 0.08), 0.014, color="steel", seg=4, caps=False)
        for sx in (-1, 1):
            m.tube((sx * (half - 0.04), f, FLOOR_T), (sx * (half - 0.04), f, top - 0.08), 0.014, color="steel",
                   seg=4, caps=False)
    for z in (0.55, 1.1):
        m.box_base((CAGE - 0.08, 0.05, 0.05), (0, half - 0.04, z), "steel_dark")
        for sx in (-1, 1):
            m.box_base((0.05, CAGE - 0.08, 0.05), (sx * (half - 0.04), 0, z), "steel_dark")
    # Hoist: pulley and cables up to the shaft top, a caged bulb, a call panel.
    m.tube((0, -0.12, top + 0.12), (0, 0.12, top + 0.12), 0.14, color="steel_dark", seg=8)
    for x in (-0.06, 0.06):
        m.tube((x, 0, top + 0.2), (x, 0, top + 1.2), 0.008, color="steel", seg=4, caps=False)
    m.box_base((0.12, 0.12, 0.08), (0, 0, top - 0.14), "lamp_warm")
    m.box_base((0.16, 0.16, 0.03), (0, 0, top - 0.06), "black")
    m.box_base((0.16, 0.06, 0.26), (half - 0.2, -half + 0.12, 1.05), "hazard_yellow")
    m.box((0.05, 0.02, 0.05), (half - 0.2, -half + 0.085, 1.24), "alert_red")
    m.box((0.05, 0.02, 0.05), (half - 0.2, -half + 0.085, 1.14), "black")
    root = m.finish()

    door = om.Mesh(p, "Door")
    dw, dh = CAGE - 0.16, CAGE_H - FLOOR_T - 0.14
    for z in (0.0, dh - 0.05):
        door.box_base((dw, 0.04, 0.05), (dw / 2, 0, z), "hazard_yellow")
    for i in range(7):
        x = dw * i / 6.0
        door.box_base((0.03, 0.03, dh), (min(max(x, 0.015), dw - 0.015), 0, 0), "steel")
    diag = math.degrees(math.atan2(dh - 0.1, dw / 3.0))
    length = math.hypot(dw / 3.0, dh - 0.1)
    for k in range(3):
        cx = dw / 6.0 + k * dw / 3.0
        door.box((0.025, 0.02, length), (cx, -0.02, dh / 2), "steel_dark", om.rot(y=90 - diag))
        door.box((0.025, 0.02, length), (cx, -0.02, dh / 2), "steel_dark", om.rot(y=diag - 90))
    door.box((0.04, 0.06, 0.25), (dw - 0.06, -0.05, 1.0), "black")
    door.finish(parent=root, location=(-half + 0.08, -half + 0.04, FLOOR_T + 0.02))
    return root


MODELS = [
    ("raised_bed.glb", make_raised_bed, "prop"),
    ("plant_stage_1.glb", make_plant_1, "plant"),
    ("plant_stage_2.glb", make_plant_2, "plant"),
    ("plant_stage_3.glb", make_plant_3, "plant"),
    ("plant_stage_4.glb", make_plant_4, "plant"),
    ("grow_lamp.glb", make_grow_lamp, "prop"),
    ("vent_duct_2m.glb", make_vent_duct, "prop"),
    ("concrete_wall_2m.glb", make_concrete_wall, "prop"),
    ("lift_cage.glb", make_lift_cage, "building"),
]


def main() -> None:
    palette = om.reset_scene()
    report = om.Report("plantation")
    built = []
    for filename, maker, budget in MODELS:
        obj = maker(palette)
        path = os.path.join(OUT, filename)
        om.export_glb(obj, path)
        report.add(obj, path, budget)
        for child in obj.children_recursive:
            child.name = obj.name + "." + child.name
        built.append(obj)
    ok = report.print()
    by_name = {o.name: o for o in built}
    # Preview: the four stages standing on a bed's soil, lamps above, the rest in a row behind.
    bed = by_name["raised_bed"]
    front = [bed, by_name["concrete_wall_2m"], by_name["lift_cage"]]
    back = [by_name["vent_duct_2m"]]
    om.layout_grid(front + back, columns=3, gap=1.0)
    for i, name in enumerate(("plant_stage_1", "plant_stage_2", "plant_stage_3", "plant_stage_4")):
        plant = by_name[name]
        plant.location = bed.location + om.Vector((-0.8 + i * 0.53, 0.0, BED_SOIL_TOP + 0.012))
    lamp = by_name["grow_lamp"]
    lamp.location = bed.location + om.Vector((0.0, 0.0, 1.6))
    om.render_preview(palette, built, "plantation.png", ground="concrete_dark", mood="plantation")
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()

"""Old Money: estate models (manor, Land Rover, wheat clump, bush, T-junction path tile, harvest pile).

Run headless from the repo root:
    "D:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python-exit-code 1 --python tools/blender/make_estate.py

Output: assets/models/field/*.glb, assets/models/plantation/harvest_pile.glb and tools/blender/previews/estate.png.
Front of every model = Godot +Z (Blender -Y).
"""

import math
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mathutils import Matrix  # noqa: E402

import om_common as om  # noqa: E402

FIELD = os.path.join(om.MODELS, "field")
PLANTATION = os.path.join(om.MODELS, "plantation")


# ---------------------------------------------------------------- roofs
def hip_roof(m: om.Mesh, center, half_x: float, half_y: float, ridge_half: float, rise: float, color,
             along_y: bool = False) -> None:
    """Closed hipped roof: eaves rectangle at center.z, ridge `ridge_half` long each way at center.z + rise.
    ridge_half == half_x gives a gable roof. `along_y` runs the ridge along Y instead of X."""
    cx, cy, z0 = center
    z1 = z0 + rise

    def p(x: float, y: float, z: float) -> tuple:
        return (cx + y, cy + x, z) if along_y else (cx + x, cy + y, z)

    a, b, r = half_x, half_y, ridge_half
    faces = [
        [p(-a, -b, z0), p(a, -b, z0), p(r, 0, z1), p(-r, 0, z1)],
        [p(a, b, z0), p(-a, b, z0), p(-r, 0, z1), p(r, 0, z1)],
        [p(a, -b, z0), p(a, b, z0), p(r, 0, z1)],
        [p(-a, b, z0), p(-a, -b, z0), p(-r, 0, z1)],
        [p(-a, -b, z0), p(-a, b, z0), p(a, b, z0), p(a, -b, z0)],
    ]
    for face in faces:
        # Swapping x and y mirrors the shape, which turns every face inside out; undo it.
        m.poly(list(reversed(face)) if along_y else face, color)


# ---------------------------------------------------------------- manor 26 x 11 x ~11
def _window(m: om.Mesh, glow: om.Mesh, x: float, y: float, z: float, w: float, h: float, lit: bool,
            facing: str = "front") -> None:
    """Sash window on a wall plane. `facing` front = -Y wall at y, side = +-X wall at x."""
    if facing == "front":
        m.box((w + 0.2, 0.08, h + 0.2), (x, y - 0.03, z), "window_frame")
        (glow if lit else m).box((w, 0.04, h), (x, y - 0.08, z), "lamp_warm" if lit else "slate")
        m.box((w + 0.35, 0.18, 0.1), (x, y - 0.08, z - h * 0.5 - 0.12), "cotswold_shadow")
    else:
        sign = 1.0 if facing == "right" else -1.0
        m.box((0.08, w + 0.2, h + 0.2), (x + sign * 0.03, y, z), "window_frame")
        (glow if lit else m).box((0.04, w, h), (x + sign * 0.08, y, z), "lamp_warm" if lit else "slate")


def make_manor(p: om.Palette):
    """Cotswold-stone country house: main block with a hipped roof, two forward wings, a portico.
    Child `WindowsGlow` holds the lit panes (hide it to darken the house)."""
    m = om.Mesh(p, "manor")
    glow = om.Mesh(p, "WindowsGlow")
    stone = {"all": "cotswold", "top": "cotswold_shadow"}
    # Main block 16 x 8, two floors and a plinth.
    mx, my, mh = 16.0, 8.0, 7.2
    m.box_base((mx + 0.3, my + 0.3, 0.5), (0, 0, 0), "cotswold_shadow")
    m.box_base((mx, my, mh), (0, 0, 0.5), stone)
    m.box_base((mx + 0.4, my + 0.4, 0.3), (0, 0, 0.5 + mh), "plaster")
    hip_roof(m, (0, 0, 0.5 + mh + 0.3), mx * 0.5 + 0.35, my * 0.5 + 0.35, mx * 0.5 - 3.6, 3.4,
             {"all": "roof_slate", "bottom": "timber"})
    # Wings 5 x 9.5 project 1.5 m in front of the main block.
    wx, wy, wh = 5.0, 9.5, 5.8
    wing_y = -0.75
    for sx in (-1, 1):
        cx = sx * (mx * 0.5 + wx * 0.5 - 0.01)
        m.box_base((wx + 0.3, wy + 0.3, 0.5), (cx, wing_y, 0), "cotswold_shadow")
        m.box_base((wx, wy, wh), (cx, wing_y, 0.5), stone)
        m.box_base((wx + 0.3, wy + 0.3, 0.25), (cx, wing_y, 0.5 + wh), "plaster")
        hip_roof(m, (cx, wing_y, 0.5 + wh + 0.25), wy * 0.5 + 0.3, wx * 0.5 + 0.3, wy * 0.5 + 0.3, 2.6,
                 {"all": "roof_slate", "bottom": "timber"}, along_y=True)
        # Gable-end window facing the forecourt, upper and lower.
        front_y = wing_y - wy * 0.5
        _window(m, glow, cx, front_y, 2.0, 1.1, 1.6, lit=sx < 0)
        _window(m, glow, cx, front_y, 4.6, 1.0, 1.3, lit=True)
        # One window on the outer side.
        _window(m, glow, cx + sx * wx * 0.5, wing_y, 2.0, 1.1, 1.6, lit=sx > 0, facing="right" if sx > 0 else "left")
    # Chimney stacks on the main roof.
    for x in (-5.2, 5.2):
        for y in (-1.4, 1.4):
            m.box_base((0.9, 0.7, 3.2), (x, y, 0.5 + mh + 1.6), {"all": "cotswold", "top": "brick_dark"})
            m.tube((x, y, 0.5 + mh + 4.8), (x, y, 0.5 + mh + 5.2), 0.14, 0.12, color="brick_dark", seg=5)
    # Front windows: two floors x five bays, the middle ground-floor bay is the door.
    front = -my * 0.5
    for i, x in enumerate((-6.0, -3.0, 0.0, 3.0, 6.0)):
        if x != 0.0:
            _window(m, glow, x, front, 2.4, 1.2, 1.9, lit=i in (0, 3, 4))
        _window(m, glow, x, front, 5.6, 1.1, 1.6, lit=i in (1, 2))
    # Door, portico with four columns, pediment and steps.
    m.box_base((1.5, 0.1, 2.6), (0, front - 0.04, 0.5), "door_green")
    m.box_base((1.9, 0.14, 0.25), (0, front - 0.06, 3.1), "window_frame")
    glow.box((1.3, 0.02, 0.35), (0, front - 0.1, 3.5), "lamp_warm")
    porch_y = front - 1.6
    for x in (-1.9, -0.7, 0.7, 1.9):
        m.tube((x, porch_y, 0.5), (x, porch_y, 3.6), 0.2, 0.17, color="plaster", seg=6, caps=False)
    m.box_base((4.6, 2.2, 0.35), (0, front - 1.0, 3.6), "plaster")
    m.prism([(-2.4, 0.0), (2.4, 0.0), (0.0, 1.2)], 0.0, 0.3, {"all": "plaster", "front": "cotswold_shadow"},
            Matrix.Translation((0, porch_y - 0.15, 3.95)) @ om.rot(x=90))
    for k in range(3):
        m.box_base((5.2 - k * 0.5, 2.8 - k * 0.6, 0.17), (0, front - 1.4 + k * 0.3, k * 0.17), "cotswold_shadow")
    # Back windows on the main block, unlit.
    for x in (-4.5, 0.0, 4.5):
        m.box((1.3, 0.08, 1.8), (x, my * 0.5 + 0.03, 2.4), "window_frame")
        m.box((1.1, 0.04, 1.6), (x, my * 0.5 + 0.08, 2.4), "slate")
    root = m.finish()
    glow.finish(parent=root)
    return root


# ---------------------------------------------------------------- Land Rover 1.9 x 2.2 x 4.4
def make_land_rover(p: om.Palette):
    """Boxy estate 4x4 in country green with a pale roof; front = -Y (Godot +Z)."""
    m = om.Mesh(p, "land_rover")
    green = "door_green"
    wheel_r, track = 0.42, 0.86
    axle_front, axle_rear = -1.35, 1.25
    # Body: lower tub, bonnet ahead, cabin behind.
    m.box_base((1.8, 4.1, 0.62), (0, 0, 0.46), {"all": green, "bottom": "steel_dark"})
    m.box_base((1.72, 1.45, 0.3), (0, -1.3, 1.08), {"all": green, "top": green})
    m.box_base((1.78, 2.6, 0.82), (0, 0.72, 1.08), green)
    m.box_base((1.84, 2.7, 0.08), (0, 0.72, 1.9), "light_grey")
    # Glass: windscreen, side windows, rear window.
    m.box((1.5, 0.04, 0.5), (0, -0.6, 1.5), "dark_grey", om.rot(x=-8))
    for sx in (-1, 1):
        m.box((0.04, 2.2, 0.42), (sx * 0.9, 0.78, 1.55), "dark_grey")
        m.box((0.03, 0.06, 0.62), (sx * 0.91, -0.1, 1.42), green)
    m.box((1.3, 0.04, 0.42), (0, 2.03, 1.55), "dark_grey")
    # Grille, headlamps, bumpers, bonnet-mounted spare.
    m.box((1.4, 0.06, 0.34), (0, -2.06, 0.95), "steel_dark")
    for sx in (-1, 1):
        m.tube((sx * 0.6, -2.04, 0.95), (sx * 0.6, -2.1, 0.95), 0.12, color="lamp_warm", seg=6)
        m.box((0.14, 0.04, 0.1), (sx * 0.7, 2.06, 0.9), "alert_red")
    m.box((1.95, 0.18, 0.16), (0, -2.12, 0.5), "steel_dark")
    m.box((1.9, 0.16, 0.14), (0, 2.1, 0.5), "steel_dark")
    m.tube((0, 2.06, 1.3), (0, 2.3, 1.3), 0.4, color="black", seg=8)
    # Wheels and arches.
    for y in (axle_front, axle_rear):
        for sx in (-1, 1):
            m.tube((sx * (track - 0.15), y, wheel_r), (sx * (track + 0.17), y, wheel_r), wheel_r, color="black", seg=8)
            m.box_base((0.12, 1.05, 0.1), (sx * 0.92, y, 0.98), "black")
    return m.finish()


# ---------------------------------------------------------------- wheat clump ~1 m wide, 0.95 m tall
def make_wheat_clump(p: om.Palette):
    """Sheaf of standing wheat: a straw body with ears poking out at different heights. Instanced in bulk."""
    m = om.Mesh(p, "wheat_clump")
    m.tube((0, 0, 0), (0, 0, 0.62), 0.32, 0.46, color={"all": "hay", "top": "wheat"}, seg=6, phase=15)
    ears = ((0.0, 0.0, 0.66, 0.36), (0.28, 0.1, 0.6, 0.3), (-0.22, 0.24, 0.58, 0.32),
            (-0.18, -0.26, 0.6, 0.28), (0.16, -0.3, 0.57, 0.3), (0.34, -0.12, 0.55, 0.26))
    for i, (x, y, z, h) in enumerate(ears):
        m.bud((x, y, z), 0.07, h, color="wheat", seg=4, twist=i * 20)
    for x, y in ((0.36, 0.22), (-0.38, 0.0), (0.0, 0.4)):
        m.tube((x * 0.8, y * 0.8, 0.0), (x, y, 0.72), 0.025, color="hay", seg=3, caps=False)
    return m.finish()


# ---------------------------------------------------------------- bush ~1.6 m
def make_bush(p: om.Palette):
    m = om.Mesh(p, "bush")
    m.blob(0.75, (0, 0, 0.62), "hedge", subdiv=2, scale=(1.1, 1.0, 0.85), jitter=0.18, seed=4)
    m.blob(0.5, (0.45, -0.2, 0.42), "grass_deep", subdiv=1, scale=(1.0, 1.0, 0.8), jitter=0.2, seed=9)
    return m.finish()


# ---------------------------------------------------------------- T-junction path tile 2 x 2
def make_path_tile_t(p: om.Palette):
    """Same dirt as path_tile_2x2. Through ruts run along X (the main road); a branch leaves towards
    Godot -Z (Blender +Y), meeting a path_tile_2x2 laid end to end along Z."""
    m = om.Mesh(p, "path_tile_t_2x2")
    m.box_base((2.0, 2.0, 0.03), (0, 0, 0), {"all": "mud", "top": "path_dirt"})
    for y in (-0.48, 0.48):
        m.box_base((2.0, 0.22, 0.004), (0, y, 0.03), "mud")
    for x in (-0.48, 0.48):
        m.box_base((0.22, 0.52, 0.004), (x, 0.74, 0.03), "mud")
    m.prism([(-0.25, -0.1), (0.2, -0.2), (0.3, 0.1), (-0.1, 0.18)], 0.03, 0.004, "mud_dark")
    for x, y, s in ((-0.8, -0.8, 0.07), (0.75, 0.1, 0.06), (0.1, 0.75, 0.05), (-0.7, 0.2, 0.06)):
        m.box_base((s, s * 0.8, s * 0.5), (x, y, 0.03), "gravel", om.rot(z=x * 50))
    return m.finish()


# ---------------------------------------------------------------- harvest pile ~0.7 m
def make_harvest_pile(p: om.Palette):
    """Loose heap of cut, unpacked buds for the packing bench."""
    m = om.Mesh(p, "harvest_pile")
    m.tube((0, 0, 0), (0, 0, 0.16), 0.36, 0.08, color={"all": "plant_ripe", "bottom": "plant_mid"}, seg=7)
    buds = ((0.0, 0.0, 0.12, 0), (0.2, 0.08, 0.04, 90), (-0.18, 0.12, 0.05, 30), (-0.1, -0.2, 0.04, 60),
            (0.16, -0.16, 0.05, 120), (0.3, -0.02, 0.0, 10), (-0.3, -0.05, 0.0, 75))
    for x, y, z, twist in buds:
        m.bud((x, y, z), 0.07, 0.2, color="plant_ripe" if twist % 60 else "hay", seg=4, twist=twist)
    return m.finish()


MODELS = [
    (FIELD, "manor.glb", make_manor, "building"),
    (FIELD, "land_rover.glb", make_land_rover, "prop"),
    (FIELD, "wheat_clump.glb", make_wheat_clump, "plant"),
    (FIELD, "bush.glb", make_bush, "prop"),
    (FIELD, "path_tile_t_2x2.glb", make_path_tile_t, "prop"),
    (PLANTATION, "harvest_pile.glb", make_harvest_pile, "plant"),
]


def main() -> None:
    palette = om.reset_scene()
    report = om.Report("estate")
    built = []
    for folder, filename, maker, budget in MODELS:
        obj = maker(palette)
        path = os.path.join(folder, filename)
        om.export_glb(obj, path)
        report.add(obj, path, budget)
        for child in obj.children_recursive:
            child.name = obj.name + "." + child.name
        built.append(obj)
    ok = report.print()
    built.sort(key=lambda o: ["harvest_pile", "wheat_clump", "bush", "path_tile_t_2x2", "land_rover", "manor"].index(o.name))
    om.layout_grid(built, columns=6, gap=1.5)
    om.render_preview(palette, built, "estate.png", ground="grass_mid", mood="dusk")
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()

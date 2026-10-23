"""Old Money: four low-poly people (static meshes, A-pose, no rig yet), colour codes from STYLE.md section 4.

Run headless from the repo root:
    "D:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python tools/blender/make_characters.py

Output: assets/models/characters/*.glb and tools/blender/previews/characters.png. Feet on the origin,
face towards Godot +Z.
"""

import math
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402

import om_common as om  # noqa: E402

OUT = os.path.join(om.MODELS, "characters")

HEM = {"long": 0.42, "mid": 0.6, "jacket": 0.78}
FLARE = {"long": 1.18, "mid": 1.1, "jacket": 1.0}

PEOPLE = [
    # Jack: long camel coat open over a navy suit, no hat.
    ("jack", dict(height=1.80, coat="camel_coat", length="long", front="navy_suit", vee="shirt_cream",
                  trousers="navy_suit", shoes="black", skin="skin_2", hair="hair_dark", hat=None,
                  cuffs="shirt_cream", collar="coat", shoulders=1.04)),
    # Plantation worker: tweed_green jacket, cap_grey flat cap.
    ("worker", dict(height=1.74, coat="tweed_green", length="jacket", front=None, vee="shirt_cream",
                    trousers="dark_grey", shoes="mud_dark", skin="skin_3", hair="hair_dark", hat="cap_grey",
                    cuffs=None, collar="shirt", shoulders=1.0)),
    # Courier: charcoal coat to the knee, dark jumper, messenger bag.
    ("courier", dict(height=1.76, coat="charcoal", length="mid", front=None, vee="dark_grey",
                     trousers="black", shoes="black", skin="skin_4", hair="hair_dark", hat=None,
                     cuffs=None, collar="coat", shoulders=0.98, bag=True)),
    # Inspector / neighbour: tweed_brown jacket, broad shoulders, flat cap, clipboard.
    ("inspector", dict(height=1.72, coat="tweed_brown", length="jacket", front=None, vee="shirt_cream",
                       trousers="cap_grey", shoes="oak", skin="skin_1", hair="light_grey", hat="tweed_brown",
                       cuffs=None, collar="shirt", shoulders=1.14, clipboard=True, tie="tie_burgundy")),
]


def _torso_colour(spec: dict):
    def pick(face) -> str:
        c = face.calc_center_median()
        if face.normal.y < -0.5 and abs(c.x) < 0.045:
            if c.z > 1.33:
                return spec["vee"]
            if spec["front"]:
                return spec["front"]
        return spec["coat"]
    return pick


def build_person(p: om.Palette, name: str, spec: dict):
    m = om.Mesh(p, name)
    sh = spec["shoulders"]
    coat = spec["coat"]
    # Shoes and legs.
    for sx in (-1, 1):
        m.box_base((0.1, 0.26, 0.075), (sx * 0.1, -0.04, 0.0), {"all": spec["shoes"]})
        m.tube((sx * 0.1, 0.0, 0.06), (sx * 0.095, 0.0, 0.92), 0.055, 0.08, color=spec["trousers"], seg=6)
    # Coat / jacket body: elliptical rings from the hem to the shoulders, one flat face looking forward.
    hem = HEM[spec["length"]]
    fl = FLARE[spec["length"]]
    rings = [(hem, 0.2 * fl, 0.14 * fl, 0.0)]
    for z, rx, ry in ((0.66, 0.195, 0.13), (0.9, 0.18, 0.12), (1.05, 0.165, 0.11), (1.25, 0.19 * sh, 0.12),
                      (1.4, 0.2 * sh, 0.115), (1.47, 0.11 * sh, 0.08)):
        if z > hem + 0.05:
            rings.append((z, rx, ry, 0.0))
    m.loft(rings, seg=10, color=_torso_colour(spec))
    if spec.get("tie"):
        m.box((0.035, 0.012, 0.16), (0.0, -0.117, 1.3), spec["tie"])
    # Collar and neck.
    if spec["collar"] == "coat":
        m.tube((0, 0.0, 1.43), (0, 0.005, 1.53), 0.088, 0.072, color=coat, seg=8, caps=False)
    else:
        m.tube((0, 0.0, 1.45), (0, 0.0, 1.51), 0.07, 0.06, color="shirt_cream", seg=8, caps=False)
    m.tube((0, 0.0, 1.44), (0, 0.0, 1.57), 0.048, color=spec["skin"], seg=6, caps=False)
    # Head, nose, ears, hair.
    m.sphere(0.105, (0, -0.005, 1.66), spec["skin"], seg=10, rings=7, scale=(0.88, 0.98, 1.12))
    m.box((0.03, 0.04, 0.05), (0, -0.105, 1.65), spec["skin"])
    for sx in (-1, 1):
        m.box((0.02, 0.04, 0.06), (sx * 0.093, 0.0, 1.66), spec["skin"])
    m.sphere(0.108, (0, 0.022, 1.7), spec["hair"], seg=10, rings=6, scale=(0.92, 0.98, 0.96))
    if spec["hat"]:
        _flat_cap(m, spec["hat"])
    # Arms in a slight A-pose, rounded shoulders, cuffs, hands.
    for sx in (-1, 1):
        s = om.Vector((sx * 0.215 * sh, 0.0, 1.41))
        e = om.Vector((sx * 0.29 * sh, 0.015, 1.12))
        w = om.Vector((sx * 0.345 * sh, 0.0, 0.86))
        m.sphere(0.062, s, coat, seg=6, rings=4)
        m.tube(s, e, 0.058, 0.05, color=coat, seg=6)
        m.tube(e, w, 0.05, 0.044, color=coat, seg=6)
        if spec["cuffs"]:
            m.tube(w - (w - e).normalized() * 0.01, w + (w - e).normalized() * 0.012, 0.046, color=spec["cuffs"],
                   seg=6, caps=False)
        hand = w + (w - e).normalized() * 0.065
        m.sphere(0.045, hand, spec["skin"], seg=6, rings=4, scale=(0.7, 0.95, 1.25))
    if spec.get("bag"):
        m.box_base((0.07, 0.28, 0.24), (0.235, 0.03, 0.84), {"all": "black", "top": "dark_grey"})
        m.tube((-0.15, -0.125, 1.43), (0.2, -0.155, 1.0), 0.016, color="dark_grey", seg=4, caps=False)
        m.tube((-0.15, 0.115, 1.43), (0.2, 0.15, 1.0), 0.016, color="dark_grey", seg=4, caps=False)
    if spec.get("clipboard"):
        hx = 0.345 * sh + 0.03
        m.box((0.02, 0.23, 0.31), (hx, -0.07, 0.86), "dead_leaf", om.rot(x=-12))
        m.box((0.006, 0.2, 0.26), (hx + 0.013, -0.072, 0.85), "white", om.rot(x=-12))
        m.box((0.016, 0.06, 0.03), (hx + 0.012, -0.04, 1.0), "steel", om.rot(x=-12))
    # Scale to the wanted height (the build above tops out around 1.8 m).
    top = max(v.co.z for v in m.bm.verts)
    k = spec["height"] / top
    bmesh.ops.scale(m.bm, vec=(k, k, k), verts=list(m.bm.verts))
    return m.finish()


def _flat_cap(m: om.Mesh, color: str) -> None:
    m.loft([(1.735, 0.104, 0.116, 0.0), (1.775, 0.11, 0.124, -0.012), (1.805, 0.086, 0.098, -0.024)],
           seg=10, color=color, cap_bottom=True, cap_top=True)
    brim = [(-0.085, -0.09), (0.085, -0.09), (0.07, -0.145), (0.03, -0.175), (-0.03, -0.175), (-0.07, -0.145)]
    tilt = om.Matrix.Translation((0, -0.1, 1.745)) @ om.rot(x=-10) @ om.Matrix.Translation((0, 0.1, -1.745))
    m.prism(brim, 1.738, 0.014, color, tilt)


def main() -> None:
    palette = om.reset_scene()
    report = om.Report("characters")
    built = []
    for name, spec in PEOPLE:
        obj = build_person(palette, name, spec)
        path = os.path.join(OUT, name + ".glb")
        om.export_glb(obj, path)
        report.add(obj, path, "character")
        built.append(obj)
    ok = report.print()
    om.layout_grid(built, columns=4, gap=0.5)
    om.render_preview(palette, built, "characters.png", ground="path_dirt", mood="dusk")
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()

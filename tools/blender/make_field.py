"""Old Money: field models (container, shelf, hedge, trees, path tile, puddle, cottage, stash crate).

Run headless from the repo root:
    "D:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python tools/blender/make_field.py

Output: assets/models/field/*.glb and tools/blender/previews/field.png. Front of every model = Godot +Z.
"""

import math
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mathutils import Matrix, Vector  # noqa: E402

import om_common as om  # noqa: E402

OUT = os.path.join(om.MODELS, "field")


# ---------------------------------------------------------------- shipping container 6 x 2.44 x 2.6
L, W, H = 6.0, 2.44, 2.6
POST = 0.15
RIDGE_PITCH = 0.28
RIDGE_DEPTH = 0.04


def _corrugation(start: float, end: float, outer: float, sign: float) -> list:
    """Points along one axis: flat out, slope in, flat in, slope out. `sign` pushes the recess inwards."""
    pts = []
    n = max(1, int(round((end - start) / RIDGE_PITCH)))
    pitch = (end - start) / n
    flat = pitch * 0.36
    slope = pitch * 0.14
    inner = outer - sign * RIDGE_DEPTH
    for i in range(n):
        a = start + i * pitch
        pts += [(a, outer), (a + flat, outer), (a + flat + slope, inner), (a + 2 * flat + slope, inner)]
    pts.append((end, outer))
    return pts


def _ridge_colour(face) -> str:
    c = face.calc_center_median()
    on_side = abs(c.y) > W * 0.5 - POST and abs(c.x) < L * 0.5 - POST * 0.5
    depth = abs(c.y) if on_side else abs(c.x)
    outer = W * 0.5 - 0.02 if on_side else L * 0.5 - 0.02
    return "container_red" if depth > outer - RIDGE_DEPTH * 0.75 else "container_rust"


def make_container(p: om.Palette):
    m = om.Mesh(p, "container")
    hx, hy = L * 0.5, W * 0.5
    z0, z1 = POST, H - POST
    # Corrugated long walls: outer skin faces out, a flat inner skin faces the inside.
    xs, xe = -hx + POST, hx - POST
    front = _corrugation(xs, xe, -(hy - 0.02), -1.0)
    m.wall_profile([(x, y) for x, y in front], z0, z1, _ridge_colour)
    back = _corrugation(xs, xe, hy - 0.02, 1.0)
    m.wall_profile([(x, y) for x, y in reversed(back)], z0, z1, _ridge_colour)
    inner = hy - 0.1
    m.wall_profile([(xe, -inner), (xs, -inner)], z0, z1, "corrugated")
    m.wall_profile([(xs, inner), (xe, inner)], z0, z1, "corrugated")
    # Closed end (-X), corrugated across.
    ys, ye = -hy + POST, hy - POST
    end = _corrugation(ys, ye, -(hx - 0.02), -1.0)
    m.wall_profile([(x, y) for y, x in reversed(end)], z0, z1, _ridge_colour)
    m.wall_profile([(-hx + 0.1, ys), (-hx + 0.1, ye)], z0, z1, "corrugated")
    # Frame: corner posts, rails, corner castings.
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box_base((POST, POST, H), (sx * (hx - POST / 2), sy * (hy - POST / 2), 0), "container_rust")
            for z in (0.0, H - 0.12):
                m.box_base((0.17, 0.17, 0.12), (sx * (hx - POST / 2), sy * (hy - POST / 2), z), "steel_dark")
    for sy in (-1, 1):
        for z in (0.0, H - POST):
            m.box_base((L - 2 * POST, 0.16, POST), (0, sy * (hy - 0.08), z), "container_rust")
        for x in (-1.0, 1.0):  # forklift pockets
            m.box((0.35, 0.02, 0.09), (x, sy * (hy + 0.001), 0.075), "black")
    for z in (0.0, H - POST):
        m.box_base((POST, W - 2 * POST, POST), (-(hx - POST / 2), 0, z), "container_rust")
    m.box_base((POST, W - 2 * POST, 0.2), (hx - POST / 2, 0, H - 0.2), "container_rust")
    m.box_base((POST, W - 2 * POST, POST), (hx - POST / 2, 0, 0), "container_rust")
    # Roof with a few low ridges, floor of oak boards.
    m.box_base((L, W, 0.06), (0, 0, H - 0.06), {"all": "container_red", "bottom": "corrugated"})
    for x in (-2.0, -1.0, 0.0, 1.0, 2.0):
        m.box_base((0.12, W - 0.4, 0.03), (x, 0, H), "container_rust")
    m.box_base((L - 2 * POST, W - 0.2, 0.05), (0, 0, POST - 0.05), {"all": "container_rust", "top": "oak"})
    root = m.finish()

    # Two door leaves, origins on their hinges so the game can swing them about local Y.
    gap = 0.05
    leaf_w = (W - 2 * POST - gap) * 0.5
    leaf_h = H - 0.2 - POST
    for name, hinge_y, dirn in (("DoorLeft", -(hy - POST), 1.0), ("DoorRight", hy - POST, -1.0)):
        d = om.Mesh(p, name)
        cy = dirn * leaf_w * 0.5
        d.box_base((0.05, leaf_w, leaf_h), (0, cy, 0), {"all": "container_red", "right": "container_red"})
        for k in range(4):  # recessed vertical panels on the outside
            y = dirn * (0.12 + k * (leaf_w - 0.24) / 3.0)
            d.box_base((0.012, 0.09, leaf_h - 0.3), (0.03, y, 0.15), "container_rust")
        for y in (dirn * leaf_w * 0.3, dirn * leaf_w * 0.72):  # locking bars, cams, handles
            d.tube((0.06, y, 0.02), (0.06, y, leaf_h - 0.02), 0.022, color="steel_dark", seg=4, phase=45)
            for z in (0.06, leaf_h - 0.06):
                d.box((0.05, 0.08, 0.06), (0.06, y, z), "steel_dark")
            d.box((0.04, 0.04, 0.3), (0.09, y - dirn * 0.08, 1.05), "steel")
        for z in (0.35, leaf_h - 0.35):  # hinges
            d.box((0.06, 0.06, 0.1), (0.0, 0.0, z), "steel_dark")
        d.finish(parent=root, location=(hx - 0.025, hinge_y, POST))

    # Warm light leaking through the gap between the leaves (STYLE: the secret glows amber).
    g = om.Mesh(p, "GapGlow")
    g.box_base((0.05, gap, leaf_h - 0.1), (0, 0, 0), "lamp_warm")
    g.finish(parent=root, location=(hx - 0.032, 0.0, POST + 0.05))
    return root


def make_container_shelf(p: om.Palette):
    """Free-standing oak shelf that hides the lift. 1.8 wide, 0.5 deep, 2.1 tall; front = -Y."""
    m = om.Mesh(p, "container_shelf")
    w, d, h = 1.8, 0.5, 2.1
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box_base((0.06, 0.06, h), (sx * (w / 2 - 0.03), sy * (d / 2 - 0.03), 0), "oak")
    shelves = (0.12, 0.7, 1.28, 1.86)
    for z in shelves:
        for k, y in enumerate((-0.16, 0.0, 0.16)):
            m.box_base((w - 0.02, 0.15, 0.03), (0, y, z), "oak" if k != 1 else "timber")
    for sx in (-1, 1):  # side rails tie the posts
        for z in (0.5, 1.6):
            m.box_base((0.04, d - 0.06, 0.05), (sx * (w / 2 - 0.03), 0, z), "timber")
    brace = math.degrees(math.atan2(h - 0.3, w - 0.1))
    m.box((math.hypot(w - 0.1, h - 0.3), 0.03, 0.05), (0, d / 2 - 0.02, h / 2), "timber", om.rot(y=-brace))
    m.box((math.hypot(w - 0.1, h - 0.3), 0.03, 0.05), (0, d / 2 - 0.05, h / 2), "timber", om.rot(y=brace))
    # Clutter: cardboard boxes, a wooden crate, paint tins, a sack.
    m.box_base((0.5, 0.38, 0.32), (-0.5, 0, 0.15), {"all": "hay", "top": "wheat"})
    m.box_base((0.42, 0.36, 0.28), (0.25, 0.02, 0.15), {"all": "dead_leaf", "top": "hay"})
    m.box_base((0.5, 0.4, 0.3), (-0.45, 0, 0.73), {"all": "oak", "top": "timber"})
    for i, x in enumerate((0.25, 0.45, 0.65)):
        m.tube((x, -0.05, 0.73), (x, -0.05, 0.93), 0.08, color="steel" if i != 1 else "hazard_yellow", seg=8)
    m.box_base((0.38, 0.32, 0.26), (0.5, 0.0, 1.31), {"all": "hay", "top": "wheat"})
    m.box_base((0.3, 0.3, 0.22), (-0.6, 0.03, 1.31), {"all": "dead_leaf", "top": "hay"})
    m.sphere(0.2, (-0.15, 0.0, 1.47), "cotswold_shadow", seg=6, rings=4, scale=(1.3, 1.0, 0.8))
    m.box_base((0.36, 0.3, 0.18), (0.3, 0.0, 1.89), {"all": "hay", "top": "wheat"})
    return m.finish()


# ---------------------------------------------------------------- nature and ground
def make_hedge(p: om.Palette):
    """2 m segment along X, ends flush so segments tile."""
    m = om.Mesh(p, "hedge_2m")

    def leafage(face) -> str:
        return "moss" if face.normal.z > 0.85 else ("grass_deep" if face.normal.z > 0.3 else "hedge")

    # Clipped profile with rounded shoulders, extruded along X (Blender) so segments butt end to end.
    profile = [(-0.47, 0.0), (0.47, 0.0), (0.44, 0.85), (0.34, 1.22), (-0.34, 1.22), (-0.44, 0.85)]
    along_x = Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    m.prism(profile, -1.0, 2.0, leafage, along_x)
    for x, w, h, turn in ((-0.6, 0.55, 0.07, 4), (0.08, 0.5, 0.1, -6), (0.68, 0.5, 0.06, 3)):
        m.box_base((w, 0.5, h), (x, 0.02, 1.22), {"all": "grass_deep", "top": "moss"}, om.rot(z=turn))
    return m.finish()


def make_conifer(p: om.Palette):
    m = om.Mesh(p, "tree_conifer")
    m.tube((0, 0, 0), (0, 0, 0.9), 0.15, 0.11, color="timber", seg=6)
    tiers = ((0.6, 2.3, 1.15, "hedge"), (1.5, 3.3, 0.9, "grass_deep"), (2.4, 4.1, 0.66, "hedge"), (3.2, 4.7, 0.4, "grass_deep"))
    for i, (z0, z1, r, col) in enumerate(tiers):
        m.tube((0, 0, z0), (0, 0, z1), r, 0.0, color=col, seg=8, phase=i * 22.5)
    return m.finish()


def make_round_tree(p: om.Palette):
    m = om.Mesh(p, "tree_round")
    m.tube((0, 0, 0), (0, 0, 1.9), 0.17, 0.12, color="timber", seg=6)
    m.tube((0, 0, 1.4), (0.5, -0.1, 2.2), 0.07, 0.05, color="timber", seg=5)
    m.tube((0, 0, 1.6), (-0.45, 0.2, 2.3), 0.07, 0.05, color="timber", seg=5)

    def leaf(face) -> str:
        return "grass_mid" if face.normal.z > 0.45 else ("hedge" if face.normal.z < -0.3 else "grass_deep")

    for i, (x, y, z, r) in enumerate(((0.0, 0.0, 3.0, 0.95), (0.7, -0.25, 2.55, 0.75), (-0.65, 0.3, 2.6, 0.75),
                                      (0.15, 0.6, 2.45, 0.7), (-0.2, -0.55, 2.35, 0.65))):
        m.blob(r, (x, y, z), leaf, subdiv=2 if i == 0 else 1, scale=(1.0, 1.0, 0.85), jitter=0.08, seed=3 + i * 4)
    return m.finish()


def make_path_tile(p: om.Palette):
    """2 x 2 m dirt path, 3 cm thick. Wheel ruts run along local Z in Godot (Blender Y) and tile end to end."""
    m = om.Mesh(p, "path_tile_2x2")
    m.box_base((2.0, 2.0, 0.03), (0, 0, 0), {"all": "mud", "top": "path_dirt"})
    for x in (-0.48, 0.48):
        m.box_base((0.22, 2.0, 0.004), (x, 0, 0.03), {"all": "mud", "top": "mud"})
    m.prism([(-0.2, -0.6), (0.15, -0.72), (0.3, -0.45), (0.05, -0.3), (-0.25, -0.38)], 0.03, 0.004, "mud")
    m.prism([(0.1, 0.35), (0.3, 0.3), (0.35, 0.55), (0.12, 0.62)], 0.03, 0.004, "mud_dark")
    for x, y, s in ((-0.75, 0.6, 0.07), (0.8, -0.2, 0.06), (-0.1, 0.05, 0.05), (0.7, 0.8, 0.08), (-0.82, -0.75, 0.06)):
        m.box_base((s, s * 0.8, s * 0.5), (x, y, 0.03), "gravel", om.rot(z=x * 50))
    return m.finish()


def _blob_outline(rx: float, ry: float, n: int, wobble: tuple) -> list:
    pts = []
    for i in range(n):
        t = 2.0 * math.pi * i / n
        k = wobble[i % len(wobble)]
        pts.append((rx * k * math.cos(t), ry * k * math.sin(t)))
    return pts


def make_puddle(p: om.Palette):
    """Muddy rim in the root; the water is the child `Water` so it can take the wet material (STYLE 2)."""
    wob = (1.0, 0.8, 0.92, 1.1, 1.18, 0.95, 0.78, 0.86, 1.05, 1.12, 0.9, 0.74, 0.88, 1.02)
    m = om.Mesh(p, "puddle")
    m.prism(_blob_outline(0.82, 0.5, 14, wob), 0.0, 0.008, "mud")
    root = m.finish()
    w = om.Mesh(p, "Water")
    w.prism(_blob_outline(0.74, 0.43, 14, wob), 0.0, 0.012, "steel")
    w.finish(parent=root)
    return root


# ---------------------------------------------------------------- stone cottage
CW, CD = 7.0, 5.0          # walls footprint (x, y)
EAVE = 3.2                 # wall top
PITCH = math.radians(40.0)
RIDGE = EAVE + (CD * 0.5) * math.tan(PITCH)


def _place(base: Matrix, local) -> Vector:
    return base @ Vector(local)


def _window(m: om.Mesh, glow: om.Mesh, base: Matrix, turn: Matrix, w: float, h: float, lit: bool = True) -> None:
    """Window on a wall whose outer face is local y = 0, facing local -Y; `base` places the window centre."""
    fr = 0.07
    for local, size in (((0, -0.03, h / 2 + fr / 2), (w + 2 * fr, 0.08, fr)),
                        ((0, -0.03, -h / 2 - fr / 2), (w + 2 * fr, 0.08, fr)),
                        ((-w / 2 - fr / 2, -0.03, 0), (fr, 0.08, h)),
                        ((w / 2 + fr / 2, -0.03, 0), (fr, 0.08, h))):
        m.box(size, _place(base, local), "window_frame", turn)
    m.box((w + 0.3, 0.14, 0.08), _place(base, (0, -0.06, -h / 2 - fr - 0.04)), "cotswold_shadow", turn)
    m.box((w + 0.36, 0.06, 0.16), _place(base, (0, -0.02, h / 2 + fr + 0.08)), "cotswold_shadow", turn)
    m.box((0.04, 0.05, h), _place(base, (0, -0.035, 0)), "window_frame", turn)
    m.box((w, 0.05, 0.04), _place(base, (0, -0.035, h * 0.12)), "window_frame", turn)
    m.box((w, 0.01, h), _place(base, (0, -0.004, 0)), "slate", turn)
    if lit:
        glow.box((w, 0.01, h), _place(base, (0, -0.012, 0)), "lamp_warm", turn)


def make_cottage(p: om.Palette):
    m = om.Mesh(p, "cottage")
    glow = om.Mesh(p, "WindowsGlow")
    hx, hy = CW * 0.5, CD * 0.5
    m.box_base((CW + 0.2, CD + 0.2, 0.3), (0, 0, 0), "cotswold_shadow")
    m.box_base((CW, CD, EAVE - 0.3), (0, 0, 0.3), "cotswold")
    # Attic: one triangular prism under the roof, its ends are the gables.
    gable = Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, EAVE), (0, 0, 0, 1)))
    m.prism([(-hy, 0.0), (hy, 0.0), (0.0, RIDGE - EAVE)], -hx, CW, "cotswold", gable)
    # Quoins: alternating corner stones.
    for sx in (-1, 1):
        for sy in (-1, 1):
            for k in range(5):
                long_x = k % 2 == 0
                size = (0.42, 0.24, 0.26) if long_x else (0.24, 0.42, 0.26)
                cx = sx * (hx - size[0] / 2 + 0.02)
                cy = sy * (hy - size[1] / 2 + 0.02)
                m.box_base(size, (cx, cy, 0.4 + k * 0.56), "cotswold_shadow")
    # Roof: two slate slabs with overhangs and a ridge cap.
    thick, over_end, over_eave = 0.14, 0.3, 0.38
    slope_len = hy / math.cos(PITCH) + over_eave
    for side in (-1, 1):
        down = Vector((0, side * math.cos(PITCH), -math.sin(PITCH)))
        normal = Vector((0, side * math.sin(PITCH), math.cos(PITCH)))
        centre = Vector((0, 0, RIDGE)) + down * (slope_len / 2) + normal * (thick / 2)
        m.box((CW + 2 * over_end, slope_len, thick), centre, {"all": "slate", "top": "roof_slate", "bottom": "timber"},
              om.rot(x=-side * math.degrees(PITCH)))
    m.box((CW + 2 * over_end + 0.04, 0.24, 0.12), (0, 0, RIDGE + thick / math.cos(PITCH) + 0.02), "slate")
    # Chimney through the +X end of the roof, two pots.
    m.box_base((0.75, 0.6, 2.6), (hx - 0.6, 0.7, RIDGE - 1.5), {"all": "brick", "top": "brick_dark"})
    m.box_base((0.85, 0.7, 0.14), (hx - 0.6, 0.7, RIDGE + 1.0), "brick_dark")
    for dx in (-0.16, 0.16):
        m.tube((hx - 0.6 + dx, 0.7, RIDGE + 1.14), (hx - 0.6 + dx, 0.7, RIDGE + 1.44), 0.08, 0.065, color="brick_dark", seg=6)

    face_front = om.rot()            # outer face at y = -hy, looking -Y
    face_back = om.rot(z=180)
    face_right = om.rot(z=90)
    face_left = om.rot(z=-90)

    def at(turn: Matrix, offset: Vector, local_x: float, z: float) -> Matrix:
        return Matrix.Translation(offset) @ turn @ Matrix.Translation((local_x, 0, z))

    front = Vector((0, -hy, 0))
    back = Vector((0, hy, 0))
    right = Vector((hx, 0, 0))
    left = Vector((-hx, 0, 0))
    _window(m, glow, at(face_front, front, -2.1, 1.75), face_front, 0.9, 1.1)
    _window(m, glow, at(face_front, front, 2.0, 1.75), face_front, 0.9, 1.1)
    _window(m, glow, at(face_back, back, -1.6, 1.75), face_back, 0.9, 1.1)
    _window(m, glow, at(face_back, back, 1.8, 1.75), face_back, 0.9, 1.1, lit=False)
    _window(m, glow, at(face_right, right, -0.6, 4.1), face_right, 0.6, 0.7)
    _window(m, glow, at(face_left, left, 0.0, 1.75), face_left, 0.9, 1.1, lit=False)
    _window(m, glow, at(face_left, left, 0.0, 4.1), face_left, 0.6, 0.7)

    # Front door with a fanlight, a canopy and a step.
    door_x = -0.1
    m.box_base((1.0, 0.08, 2.05), (door_x, -hy - 0.02, 0.3), "door_green")
    for dx in (-0.57, 0.57):
        m.box_base((0.12, 0.1, 2.45), (door_x + dx, -hy - 0.03, 0.3), "window_frame")
    m.box_base((1.26, 0.1, 0.1), (door_x, -hy - 0.03, 2.65), "window_frame")
    m.box((0.06, 0.05, 0.06), (door_x + 0.35, -hy - 0.08, 1.3), "brass")
    m.box((0.98, 0.01, 0.28), (door_x, -hy - 0.005, 2.5), "slate")
    glow.box((0.98, 0.01, 0.28), (door_x, -hy - 0.012, 2.5), "lamp_warm")
    m.box_base((1.5, 0.5, 0.12), (door_x, -hy - 0.35, 0.18), "cotswold_shadow")
    m.box((1.6, 0.75, 0.08), (door_x, -hy - 0.33, 2.95), {"all": "slate", "top": "roof_slate"}, om.rot(x=-12))
    for dx in (-0.72, 0.72):
        m.box((0.06, 0.5, 0.06), (door_x + dx, -hy - 0.25, 2.8), "timber", om.rot(x=30))
    root = m.finish()
    glow.finish(parent=root)
    return root


# ---------------------------------------------------------------- stash crate
def make_stash_crate(p: om.Palette):
    """0.7 x 0.45 x 0.42 plank crate; `Lid` is hinged on its back edge (rotate about local X in Godot)."""
    m = om.Mesh(p, "stash_crate")
    w, d, h = 0.7, 0.45, 0.38
    m.box_base((w - 0.02, d - 0.02, 0.03), (0, 0, 0.0), "timber")
    for z, col in ((0.03, "oak"), (0.21, "oak")):
        for side in (-1, 1):
            m.box_base((w, 0.02, 0.17), (0, side * (d / 2 - 0.01), z), col)
            m.box_base((0.02, d - 0.04, 0.17), (side * (w / 2 - 0.01), 0, z), col)
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box_base((0.045, 0.045, h), (sx * (w / 2 - 0.005), sy * (d / 2 - 0.005), 0), "timber")
    for sx in (-1, 1):
        m.box((0.03, 0.12, 0.03), (sx * (w / 2 + 0.02), 0, 0.28), "steel_dark")
    m.box((0.06, 0.02, 0.06), (0, -d / 2 - 0.012, h - 0.04), "brass")
    root = m.finish()
    lid = om.Mesh(p, "Lid")
    # Local origin = back top edge of the box.
    plank = (d + 0.02) / 3.0
    for k in range(3):
        lid.box_base((w + 0.02, plank - 0.006, 0.035), (0, -d / 2 + (k - 1) * plank, 0), "oak")
    for x in (-w / 2 + 0.08, w / 2 - 0.08):
        lid.box_base((0.06, d - 0.04, 0.025), (x, -d / 2, 0.035), "timber")
    lid.box((0.06, 0.02, 0.07), (0, -d - 0.004, 0.0), "brass")
    lid.finish(parent=root, location=(0, d / 2, h))
    return root


MODELS = [
    ("container.glb", make_container, "building"),
    ("container_shelf.glb", make_container_shelf, "prop"),
    ("hedge_2m.glb", make_hedge, "prop"),
    ("tree_conifer.glb", make_conifer, "prop"),
    ("tree_round.glb", make_round_tree, "prop"),
    ("path_tile_2x2.glb", make_path_tile, "prop"),
    ("puddle.glb", make_puddle, "prop"),
    ("cottage.glb", make_cottage, "building"),
    ("stash_crate.glb", make_stash_crate, "prop"),
]


def main() -> None:
    palette = om.reset_scene()
    report = om.Report("field")
    built = []
    for filename, maker, budget in MODELS:
        obj = maker(palette)
        path = os.path.join(OUT, filename)
        om.export_glb(obj, path)
        report.add(obj, path, budget)
        # Free the children's plain names (Door*, Lid, Water) for later models in this file.
        for child in obj.children_recursive:
            child.name = obj.name + "." + child.name
        built.append(obj)
    ok = report.print()
    order = ["stash_crate", "puddle", "path_tile_2x2", "hedge_2m", "container_shelf",
             "cottage", "container", "tree_round", "tree_conifer"]
    built.sort(key=lambda o: order.index(o.name))
    # Preview only: turn the container so its door end (and the glowing gap) faces the camera.
    built[order.index("container")].rotation_euler.z = math.pi
    om.layout_grid(built, columns=5, gap=1.2)
    om.render_preview(palette, built, "field.png", ground="grass_mid", mood="dusk")
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()

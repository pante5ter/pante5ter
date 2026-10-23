"""Shared helpers for the Old Money bpy model scripts (see README.md in this folder).

Every face is UV'd to the centre of one swatch of res://assets/textures/palette_atlas.png, so a model needs
no texture of its own. Two materials only: `om_palette` (the atlas) and `om_palette_emissive` (the atlas as
base colour AND emission), the latter used automatically for the swatches palette.json marks emissive.

Axes: Blender Z up, model front = Blender -Y. The glTF exporter turns that into Godot +Y up, front = +Z.
"""

import json
import math
import os
import random
import struct

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MODELS = os.path.join(ROOT, "assets", "models")
PREVIEWS = os.path.join(ROOT, "tools", "blender", "previews")
ATLAS_PATH = os.path.join(ROOT, "assets", "textures", "palette_atlas.png")

with open(os.path.join(ROOT, "assets", "textures", "palette.json"), encoding="utf-8") as _f:
    SWATCHES = json.load(_f)["swatches"]

# STYLE.md section 3.
BUDGETS = {
    "prop": (50, 500),
    "building": (500, 2000),
    "character": (600, 1500),
    "plant": (30, 150),
}


def uv_of(color: str) -> tuple:
    u, v = SWATCHES[color]["uv"]
    # palette.json measures v from the top; Blender from the bottom.
    return (u, 1.0 - v)


def is_emissive(color: str) -> bool:
    return bool(SWATCHES[color]["emissive"])


def srgb_hex_to_linear(hexv: str) -> tuple:
    def lin(c: float) -> float:
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    h = hexv.lstrip("#")
    return tuple(lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


# ---------------------------------------------------------------- scene and materials
class Palette:
    def __init__(self) -> None:
        image = bpy.data.images.load(ATLAS_PATH, check_existing=True)
        image.name = "palette_atlas"
        self.image = image
        self.base = self._material("om_palette", emissive=False)
        self.emissive = self._material("om_palette_emissive", emissive=True)

    def _material(self, name: str, emissive: bool) -> bpy.types.Material:
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        mat.use_backface_culling = True
        nodes = mat.node_tree.nodes
        bsdf = nodes.get("Principled BSDF")
        bsdf.inputs["Roughness"].default_value = 0.9
        bsdf.inputs["Metallic"].default_value = 0.0
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = self.image
        tex.interpolation = "Closest"
        links = mat.node_tree.links
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if emissive:
            links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 1.0
        return mat

    def set_preview_glow(self, strength: float) -> None:
        self.emissive.node_tree.nodes.get("Principled BSDF").inputs["Emission Strength"].default_value = strength


def reset_scene() -> Palette:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return Palette()


# ---------------------------------------------------------------- mesh builder
def _face_key(normal: Vector) -> str:
    if normal.z > 0.7:
        return "top"
    if normal.z < -0.7:
        return "bottom"
    if abs(normal.x) >= abs(normal.y):
        return "right" if normal.x > 0 else "left"
    return "back" if normal.y > 0 else "front"


def _pick(spec, face) -> str:
    if isinstance(spec, str):
        return spec
    if callable(spec):
        return spec(face)
    key = _face_key(face.normal)
    if key in spec:
        return spec[key]
    if key in ("left", "right", "front", "back") and "side" in spec:
        return spec["side"]
    return spec["all"]


def rot(x: float = 0.0, y: float = 0.0, z: float = 0.0) -> Matrix:
    """Euler XYZ in degrees as a 4x4 matrix."""
    return Euler((math.radians(x), math.radians(y), math.radians(z)), "XYZ").to_matrix().to_4x4()


class Mesh:
    """One object's geometry. Colour specs: a swatch name, a dict keyed by face direction
    (top/bottom/front/back/left/right, with `side` and `all` as fallbacks), or a callable(face) -> name."""

    def __init__(self, palette: Palette, name: str) -> None:
        self.palette = palette
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    # -- bookkeeping
    def _faces(self) -> set:
        return set(self.bm.faces)

    def _commit(self, before: set, color, matrix: Matrix = None) -> list:
        faces = [f for f in self.bm.faces if f not in before]
        verts = list({v for f in faces for v in f.verts})
        if matrix is not None:
            bmesh.ops.transform(self.bm, matrix=matrix, verts=verts)
        for f in faces:
            f.normal_update()
        self.paint(faces, color)
        return faces

    def paint(self, faces: list, color) -> None:
        for f in faces:
            name = _pick(color, f)
            u, v = uv_of(name)
            f.smooth = False
            f.material_index = 1 if is_emissive(name) else 0
            for loop in f.loops:
                loop[self.uv].uv = (u, v)

    # -- primitives
    def box(self, size, center=(0, 0, 0), color="concrete", matrix: Matrix = None) -> list:
        """Axis-aligned box of `size` around `center`; `matrix` (e.g. rot()) turns it about its own centre."""
        before = self._faces()
        bmesh.ops.create_cube(self.bm, size=1.0)
        m = Matrix.Translation(Vector(center)) @ (matrix if matrix is not None else Matrix()) @ Matrix.Diagonal((*size, 1.0))
        return self._commit(before, color, m)

    def box_base(self, size, base=(0, 0, 0), color="concrete", matrix: Matrix = None) -> list:
        """Box standing on `base` (centre of its bottom face)."""
        return self.box(size, (base[0], base[1], base[2] + size[2] * 0.5), color, matrix)

    def tube(self, p0, p1, r0, r1=None, color="steel", seg=6, caps=True, phase=0.0) -> list:
        """Cylinder or cone from point p0 to p1 (radius r0 at p0, r1 at p1)."""
        r1 = r0 if r1 is None else r1
        a, b = Vector(p0), Vector(p1)
        d = b - a
        length = d.length
        before = self._faces()
        bm = self.bm
        ring0, ring1 = [], []
        apex = bm.verts.new((0.0, 0.0, length)) if r1 == 0 else None
        for i in range(seg):
            t = 2.0 * math.pi * i / seg + math.radians(phase)
            c, s = math.cos(t), math.sin(t)
            ring0.append(bm.verts.new((r0 * c, r0 * s, 0.0)))
            ring1.append(apex if apex is not None else bm.verts.new((r1 * c, r1 * s, length)))
        for i in range(seg):
            j = (i + 1) % seg
            if apex is None:
                bm.faces.new((ring0[i], ring0[j], ring1[j], ring1[i]))
            else:
                bm.faces.new((ring0[i], ring0[j], apex))
        if caps:
            bm.faces.new(list(reversed(ring0)))
            if r1 > 0:
                bm.faces.new(ring1)
        align = d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
        return self._commit(before, color, Matrix.Translation(a) @ align)

    def sphere(self, radius, center=(0, 0, 0), color="concrete", seg=8, rings=6, scale=(1, 1, 1),
               matrix: Matrix = None) -> list:
        before = self._faces()
        bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=radius)
        m = Matrix.Translation(Vector(center)) @ (matrix if matrix is not None else Matrix()) @ Matrix.Diagonal((*scale, 1.0))
        return self._commit(before, color, m)

    def blob(self, radius, center=(0, 0, 0), color="hedge", subdiv=1, scale=(1, 1, 1), jitter=0.15, seed=1) -> list:
        """Lumpy icosphere for foliage."""
        before = self._faces()
        bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=radius)
        rng = random.Random(seed)
        new_verts = {v for f in self.bm.faces if f not in before for v in f.verts}
        for v in sorted(new_verts, key=lambda v: (round(v.co.x, 5), round(v.co.y, 5), round(v.co.z, 5))):
            v.co *= 1.0 + jitter * (rng.random() * 2.0 - 1.0)
        m = Matrix.Translation(Vector(center)) @ Matrix.Diagonal((*scale, 1.0))
        return self._commit(before, color, m)

    def prism(self, points, z0, height, color="oak", matrix: Matrix = None) -> list:
        """Flat shape: `points` (x, y) counter-clockwise from above, extruded `height` up from z0."""
        before = self._faces()
        bm = self.bm
        bottom = [bm.verts.new((x, y, z0)) for x, y in points]
        top = [bm.verts.new((x, y, z0 + height)) for x, y in points]
        bm.faces.new(list(reversed(bottom)))
        bm.faces.new(top)
        n = len(points)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((bottom[i], bottom[j], top[j], top[i]))
        return self._commit(before, color, matrix)

    def poly(self, points, color="concrete") -> list:
        """One face through 3D `points`, counter-clockwise seen from the side it faces."""
        before = self._faces()
        self.bm.faces.new([self.bm.verts.new(p) for p in points])
        return self._commit(before, color)

    def wall_profile(self, points, z0, z1, color="concrete") -> list:
        """Vertical strip through 2D `points`; faces point to the right of the walking direction
        (walking +X they face -Y)."""
        before = self._faces()
        bm = self.bm
        bottom = [bm.verts.new((x, y, z0)) for x, y in points]
        top = [bm.verts.new((x, y, z1)) for x, y in points]
        for i in range(len(points) - 1):
            bm.faces.new((bottom[i], bottom[i + 1], top[i + 1], top[i]))
        return self._commit(before, color)

    def loft(self, rings, seg=8, color="charcoal", cap_bottom=True, cap_top=True, phase=None) -> list:
        """Stack of elliptical rings [(z, rx, ry, y_offset), ...] joined by quads. With the default phase one
        flat face looks straight at -Y (the front), which band colour callbacks can find via `front_face`."""
        phase = (90.0 + 180.0 / seg) if phase is None else phase
        before = self._faces()
        bm = self.bm
        loops = []
        for z, rx, ry, oy in rings:
            ring = []
            for i in range(seg):
                t = math.radians(phase) + 2.0 * math.pi * i / seg
                ring.append(bm.verts.new((rx * math.cos(t), oy + ry * math.sin(t), z)))
            loops.append(ring)
        for k in range(len(loops) - 1):
            for i in range(seg):
                j = (i + 1) % seg
                bm.faces.new((loops[k][i], loops[k][j], loops[k + 1][j], loops[k + 1][i]))
        if cap_bottom:
            bm.faces.new(list(reversed(loops[0])))
        if cap_top:
            bm.faces.new(loops[-1])
        return self._commit(before, color)

    def leaf_star(self, center, radius, points=5, lift=0.04, droop=0.05, thickness=0.012, inner=0.32,
                  twist=0.0, color="plant_mid") -> list:
        """Stylised leaf cluster: a star whose centre rises and whose tips droop; closed underneath."""
        before = self._faces()
        bm = self.bm
        cx, cy, cz = center
        ring = []
        for i in range(points * 2):
            t = math.radians(twist) + math.pi * i / points
            r = radius if i % 2 == 0 else radius * inner
            dz = -droop if i % 2 == 0 else 0.0
            ring.append(bm.verts.new((cx + r * math.cos(t), cy + r * math.sin(t), cz + dz)))
        top = bm.verts.new((cx, cy, cz + lift))
        under = bm.verts.new((cx, cy, cz + lift - thickness * 2.0))
        n = len(ring)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((top, ring[i], ring[j]))
            bm.faces.new((under, ring[j], ring[i]))
        return self._commit(before, color)

    def bud(self, center, radius, height, color="hay", seg=4, twist=0.0) -> list:
        """Double cone (an elongated bead)."""
        cx, cy, cz = center
        before = self._faces()
        bm = self.bm
        ring = []
        for i in range(seg):
            t = math.radians(twist) + 2.0 * math.pi * i / seg
            ring.append(bm.verts.new((cx + radius * math.cos(t), cy + radius * math.sin(t), cz + height * 0.4)))
        lo = bm.verts.new((cx, cy, cz))
        hi = bm.verts.new((cx, cy, cz + height))
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((hi, ring[i], ring[j]))
            bm.faces.new((lo, ring[j], ring[i]))
        return self._commit(before, color)

    # -- output
    def finish(self, parent: bpy.types.Object = None, location=(0, 0, 0)) -> bpy.types.Object:
        mesh = bpy.data.meshes.new(self.name)
        self.bm.normal_update()
        self.bm.to_mesh(mesh)
        self.bm.free()
        used_emissive = any(p.material_index == 1 for p in mesh.polygons)
        mesh.materials.append(self.palette.base)
        if used_emissive:
            mesh.materials.append(self.palette.emissive)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        if parent is not None:
            obj.parent = parent
        obj.location = location
        return obj


# ---------------------------------------------------------------- export and checks
def tris_of(obj: bpy.types.Object) -> int:
    total = 0
    for o in [obj] + [c for c in obj.children_recursive if c.type == "MESH"]:
        for poly in o.data.polygons:
            total += len(poly.vertices) - 2
    return total


def export_glb(obj: bpy.types.Object, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for o in bpy.context.scene.objects:
        o.select_set(False)
    obj.select_set(True)
    for child in obj.children_recursive:
        child.select_set(True)
    saved = obj.location.copy()
    obj.location = (0, 0, 0)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=False, export_cameras=False, export_lights=False)
    obj.location = saved
    link_shared_atlas(path)


def link_shared_atlas(path: str) -> None:
    """The exporter always embeds the atlas; Godot would then extract one copy per model. Replace the
    embedded image with a relative URI to assets/textures/palette_atlas.png so every model shares it."""
    with open(path, "rb") as f:
        data = f.read()
    json_len = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + json_len])
    bin_start = 20 + json_len + 8
    blob = data[bin_start:bin_start + struct.unpack_from("<I", data, 20 + json_len)[0]]
    uri = os.path.relpath(ATLAS_PATH, os.path.dirname(path)).replace("\\", "/")
    dropped = sorted({img.pop("bufferView") for img in doc.get("images", []) if "bufferView" in img})
    for img in doc.get("images", []):
        if "uri" not in img:
            img.pop("mimeType", None)
            img["uri"] = uri
    if not dropped:
        return
    views = doc["bufferViews"]
    remap, kept, out = {}, [], bytearray()
    for i, view in enumerate(views):
        if i in dropped:
            continue
        start = view.get("byteOffset", 0)
        chunk = blob[start:start + view["byteLength"]]
        while len(out) % 4:
            out.append(0)
        view["byteOffset"] = len(out)
        out += chunk
        remap[i] = len(kept)
        kept.append(view)
    doc["bufferViews"] = kept
    for acc in doc.get("accessors", []):
        if "bufferView" in acc:
            acc["bufferView"] = remap[acc["bufferView"]]
    while len(out) % 4:
        out.append(0)
    doc["buffers"][0]["byteLength"] = len(out)
    text = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    text += b" " * ((4 - len(text) % 4) % 4)
    total = 12 + 8 + len(text) + 8 + len(out)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<I4s", len(text), b"JSON") + text)
        f.write(struct.pack("<I4s", len(out), b"BIN\x00") + bytes(out))


class Report:
    def __init__(self, title: str) -> None:
        self.title = title
        self.rows = []

    def add(self, obj: bpy.types.Object, path: str, budget: str) -> None:
        tris = tris_of(obj)
        lo, hi = BUDGETS[budget]
        dims = obj.dimensions
        # Children may stick out of the root's own bounds; measure the whole hierarchy.
        size = hierarchy_size(obj)
        self.rows.append((os.path.relpath(path, ROOT).replace("\\", "/"), tris, budget, lo <= tris <= hi, size))

    def print(self) -> bool:
        ok = True
        print("==== %s ====" % self.title)
        for path, tris, budget, fine, size in self.rows:
            flag = "ok" if fine else "OUT OF BUDGET %s" % (BUDGETS[budget],)
            print("MODEL %-48s tris %5d  %-9s %s  size(x,y,z) %.2f x %.2f x %.2f"
                  % (path, tris, budget, flag, size[0], size[1], size[2]))
            ok = ok and fine and os.path.exists(os.path.join(ROOT, path))
        print("ALL OK" if ok else "SOME MODELS FAILED THE CHECK")
        return ok


def hierarchy_bounds(obj: bpy.types.Object) -> tuple:
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in [obj] + [c for c in obj.children_recursive if c.type == "MESH"]:
        for corner in o.bound_box:
            w = o.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def hierarchy_size(obj: bpy.types.Object) -> tuple:
    bpy.context.view_layer.update()
    lo, hi = hierarchy_bounds(obj)
    return tuple(hi - lo)


# ---------------------------------------------------------------- preview render
def _set_engine(scene) -> str:
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "CYCLES"):
        try:
            scene.render.engine = engine
            return engine
        except TypeError:
            continue
    return scene.render.engine


def layout_grid(objects: list, columns: int, gap: float) -> None:
    """Rows of models along X, rows stepping back along +Y."""
    bpy.context.view_layer.update()
    y = 0.0
    for start in range(0, len(objects), columns):
        row = objects[start:start + columns]
        sizes = [hierarchy_size(o) for o in row]
        depth = max(s[1] for s in sizes)
        x = 0.0
        for obj, s in zip(row, sizes):
            obj.location = (x + s[0] * 0.5, y + depth * 0.5, 0.0)
            x += s[0] + gap
        y += depth + gap
    # Centre the whole layout on the origin.
    bpy.context.view_layer.update()
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in objects:
        a, b = hierarchy_bounds(o)
        lo = Vector(map(min, lo, a))
        hi = Vector(map(max, hi, b))
    shift = (lo + hi) * 0.5
    for o in objects:
        o.location.x -= shift.x
        o.location.y -= shift.y


def render_preview(palette: Palette, objects: list, filename: str, ground: str, mood: str = "dusk",
                   resolution=(1600, 1000), out_dir: str = PREVIEWS, azimuth: float = 35.0) -> str:
    """Perspective camera tilted 45 degrees, narrow FOV (STYLE.md 6), dusk or plantation light (STYLE.md 5)."""
    scene = bpy.context.scene
    engine = _set_engine(scene)
    if engine == "CYCLES":
        scene.cycles.samples = 48
    else:
        try:
            scene.eevee.taa_render_samples = 32
        except AttributeError:
            pass
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.film_transparent = False
    try:
        scene.view_settings.view_transform = "AgX"
    except TypeError:
        pass
    palette.set_preview_glow(1.6)

    bpy.context.view_layer.update()
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in objects:
        a, b = hierarchy_bounds(o)
        lo = Vector(map(min, lo, a))
        hi = Vector(map(max, hi, b))
    centre = (lo + hi) * 0.5
    extent = hi - lo

    ground_mesh = Mesh(palette, "preview_ground")
    gx, gy = extent.x + 6.0, extent.y + 6.0
    ground_mesh.box((gx, gy, 0.02), (centre.x, centre.y, -0.011), ground)
    ground_mesh.finish()

    world = bpy.data.worlds.new("preview_world")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if mood == "dusk":
        bg.inputs["Color"].default_value = (*srgb_hex_to_linear("#5E6A7A"), 1.0)
        bg.inputs["Strength"].default_value = 1.3
        sun = bpy.data.lights.new("sun", "SUN")
        sun.color = srgb_hex_to_linear("#F0B37A")
        sun.energy = 3.2
        sun.angle = math.radians(3.0)
        sun_obj = bpy.data.objects.new("sun", sun)
        sun_obj.rotation_euler = Euler((math.radians(68.0), 0.0, math.radians(-35.0)), "XYZ")
        scene.collection.objects.link(sun_obj)
    else:
        bg.inputs["Color"].default_value = (*srgb_hex_to_linear("#2A2622"), 1.0)
        bg.inputs["Strength"].default_value = 1.4
        for i, dx in enumerate((-0.33, 0.0, 0.33)):
            light = bpy.data.lights.new("lamp_%d" % i, "AREA")
            light.color = srgb_hex_to_linear("#F2C46B")
            light.energy = 120.0 + 20.0 * extent.x
            light.size = max(2.0, extent.x * 0.25)
            lobj = bpy.data.objects.new("lamp_%d" % i, light)
            lobj.location = (centre.x + dx * extent.x, centre.y, hi.z + 1.5)
            scene.collection.objects.link(lobj)

    cam_data = bpy.data.cameras.new("preview_cam")
    cam_data.lens_unit = "FOV"
    cam_data.angle = math.radians(28.0)
    cam = bpy.data.objects.new("preview_cam", cam_data)
    scene.collection.objects.link(cam)
    # 45 degrees down, from the front-left like the style mock; then fit every model into the frame.
    direction = Vector((-math.sin(math.radians(azimuth)), -math.cos(math.radians(azimuth)), 0.0)) * math.cos(math.radians(45.0))
    direction.z = math.sin(math.radians(45.0))
    direction.normalize()
    target = Vector((centre.x, centre.y, lo.z + extent.z * 0.3))
    distance = max(extent.length, 2.0) * 2.0
    scene.camera = cam
    corners = [Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    from bpy_extras.object_utils import world_to_camera_view
    for _ in range(12):
        cam.location = target + direction * distance
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        bpy.context.view_layer.update()
        proj = [world_to_camera_view(scene, cam, c) for c in corners]
        x0, x1 = min(p.x for p in proj), max(p.x for p in proj)
        y0, y1 = min(p.y for p in proj), max(p.y for p in proj)
        right = cam.matrix_world.to_3x3() @ Vector((1, 0, 0))
        up = cam.matrix_world.to_3x3() @ Vector((0, 1, 0))
        half_w = distance * math.tan(cam_data.angle * 0.5)
        half_h = half_w * resolution[1] / resolution[0]
        target += right * ((x0 + x1) * 0.5 - 0.5) * 2.0 * half_w + up * ((y0 + y1) * 0.5 - 0.5) * 2.0 * half_h
        distance *= max(x1 - x0, y1 - y0) / 0.9
    scene.camera = cam

    os.makedirs(out_dir, exist_ok=True)
    if out_dir == PREVIEWS:
        gdignore = os.path.join(PREVIEWS, ".gdignore")
        if not os.path.exists(gdignore):
            open(gdignore, "w").close()
    path = os.path.join(out_dir, filename)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("PREVIEW %s (%s)" % (path, engine))
    return path

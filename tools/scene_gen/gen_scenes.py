"""Generates the actor, plot, field and plantation .tscn files. Run: python tools/scene_gen/gen_scenes.py"""
import math

import os

# Scenes are written relative to the repo root, two levels above this script.
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..') + os.sep

PAL = {
    'grass_mid': (0.337, 0.447, 0.290), 'grass_deep': (0.243, 0.353, 0.227), 'mud': (0.369, 0.294, 0.227),
    'cotswold': (0.788, 0.698, 0.494), 'roof_slate': (0.231, 0.247, 0.278), 'concrete': (0.435, 0.431, 0.416),
    'concrete_dark': (0.290, 0.286, 0.275), 'oak': (0.478, 0.353, 0.227), 'timber': (0.290, 0.227, 0.173),
    'hay': (0.725, 0.643, 0.416), 'pot_black': (0.149, 0.153, 0.165), 'police_blue': (0.184, 0.365, 0.620),
    'lamp_warm': (0.949, 0.769, 0.420), 'soil': (0.227, 0.173, 0.133), 'light_grey': (0.710, 0.710, 0.690),
    'gravel': (0.549, 0.529, 0.486), 'path_dirt': (0.490, 0.400, 0.314),
}


class Scene:
    def __init__(self):
        self.ext = []
        self.sub = []
        self.nodes = []
        self._ext_ids = {}

    def ext_res(self, kind, path):
        key = (kind, path)
        if key not in self._ext_ids:
            rid = f'{len(self._ext_ids) + 1}_{path.split("/")[-1].split(".")[0].replace("-", "_")}'
            self._ext_ids[key] = rid
            self.ext.append(f'[ext_resource type="{kind}" path="{path}" id="{rid}"]')
        return f'ExtResource("{self._ext_ids[key]}")'

    def script(self, path):
        return self.ext_res('Script', path)

    def scene(self, path):
        return self.ext_res('PackedScene', path)

    def sub_res(self, kind, rid, **props):
        lines = [f'[sub_resource type="{kind}" id="{rid}"]'] + [f'{k} = {v}' for k, v in props.items()]
        self.sub.append('\n'.join(lines))
        return f'SubResource("{rid}")'

    def material(self, name, emission=False, roughness=0.9):
        r, g, b = PAL[name]
        props = {'albedo_color': f'Color({r}, {g}, {b}, 1)', 'roughness': roughness}
        if emission:
            props.update({'emission_enabled': 'true', 'emission': f'Color({r}, {g}, {b}, 1)', 'emission_energy_multiplier': 2.0})
        return self.sub_res('StandardMaterial3D', f'mat_{name}{"_glow" if emission else ""}', **props)

    def node(self, name, kind=None, parent=None, instance=None, node_paths=None, **props):
        head = f'[node name="{name}"'
        if kind:
            head += f' type="{kind}"'
        if parent is not None:
            head += f' parent="{parent}"'
        if node_paths:
            head += ' node_paths=PackedStringArray(' + ', '.join(f'"{p}"' for p in node_paths) + ')'
        if instance:
            head += f' instance={instance}'
        head += ']'
        self.nodes.append('\n'.join([head] + [f'{k} = {v}' for k, v in props.items()]))

    def write(self, path):
        text = '[gd_scene format=3]\n\n' + '\n'.join(self.ext) + '\n\n' + '\n\n'.join(self.sub) + '\n\n' + '\n\n'.join(self.nodes) + '\n'
        open(ROOT + path, 'w', encoding='utf-8', newline='').write(text.replace('\n', '\r\n'))


def v3(x, y, z):
    return f'Vector3({x}, {y}, {z})'


def xform(scale=1.0, yaw_deg=0.0, pos=(0, 0, 0)):
    props = {'position': v3(*pos)}
    if yaw_deg:
        props['rotation'] = v3(0, round(math.radians(yaw_deg), 6), 0)
    if scale != 1.0:
        props['scale'] = v3(scale, scale, scale)
    return props


def label(sc, parent, text, y, size=36, color=None):
    props = {'position': v3(0, y, 0), 'pixel_size': 0.008, 'billboard': 1, 'no_depth_test': 'true', 'text': f'"{text}"', 'font_size': size, 'outline_size': 10}
    if color:
        props['modulate'] = color
    sc.node('Label', 'Label3D', parent, **props)


def static_box(sc, name, parent, pos, size, layer=1, mesh_mat=None, script=None, node_paths=None, extra=None):
    props = {'position': v3(*pos), 'collision_layer': layer, 'collision_mask': 0}
    if script:
        props['script'] = script
    if extra:
        props.update(extra)
    sc.node(name, 'StaticBody3D', parent, node_paths=node_paths, **props)
    shape = sc.sub_res('BoxShape3D', f'shape_{name}', size=v3(*size))
    full = f'{parent}/{name}' if parent != '.' else name
    sc.node('Shape', 'CollisionShape3D', full, position=v3(0, size[1] / 2 if pos[1] == 0 else 0, 0), shape=shape)
    if mesh_mat:
        mesh = sc.sub_res('BoxMesh', f'mesh_{name}', size=v3(*size))
        sc.node('Mesh', 'MeshInstance3D', full, position=v3(0, size[1] / 2 if pos[1] == 0 else 0, 0), mesh=mesh, **{'surface_material_override/0': sc.material(mesh_mat)})
    return full


def person(sc, parent, mesh_path):
    sc.node('Model', 'Node3D', parent, script=sc.script('res://scenes/common/character_model.gd'))
    sc.node('Mesh', None, 'Model' if parent == '.' else f'{parent}/Model', instance=sc.scene(mesh_path))


# ======================================================================== actors
def actor(path, name, mesh, script, speed, extra_nodes=None, extra_props=None, node_paths=('agent', 'model')):
    sc = Scene()
    props = {'script': sc.script(script), 'speed': speed, 'agent': 'NodePath("Agent")', 'model': 'NodePath("Model")'}
    if extra_props:
        props.update(extra_props)
    sc.node(name, 'Node3D', node_paths=list(node_paths), **props)
    sc.node('Agent', 'NavigationAgent3D', '.', path_desired_distance=0.3, target_desired_distance=0.35)
    person(sc, '.', mesh)
    if extra_nodes:
        extra_nodes(sc)
    sc.write(path)


actor('scenes/actors/jack.tscn', 'Jack', 'res://assets/models/characters/jack.glb', 'res://scenes/common/walker.gd', 4.0)
actor('scenes/actors/farmhand.tscn', 'Farmhand', 'res://assets/models/characters/worker.glb', 'res://scenes/common/walker.gd', 3.0)


def worker_extras(sc):
    capsule = sc.sub_res('CapsuleShape3D', 'shape_body', radius=0.45, height=1.8)
    sc.node('Talk', 'StaticBody3D', '.', collision_layer=0, collision_mask=0, script=sc.script('res://scenes/plantation/worker_talk.gd'))
    sc.node('Shape', 'CollisionShape3D', 'Talk', position=v3(0, 0.9, 0), shape=capsule)
    sc.node('Status', 'Label3D', '.', position=v3(0, 2.3, 0), pixel_size=0.008, billboard=1, no_depth_test='true', modulate='Color(0.8, 1, 0.8, 1)', outline_modulate='Color(0, 0, 0, 1)', font_size=36, outline_size=10)


actor('scenes/actors/worker.tscn', 'Worker', 'res://assets/models/characters/worker.glb', 'res://scenes/plantation/worker_view.gd', 3.0,
      extra_nodes=worker_extras, extra_props={'status_label': 'NodePath("Status")', 'talk': 'NodePath("Talk")'}, node_paths=('status_label', 'talk', 'agent', 'model'))

# ======================================================================== plot view
sc = Scene()
stage_ext = [sc.scene(f'res://assets/models/plantation/plant_stage_{i}.glb') for i in range(1, 5)]
water = sc.sub_res('StandardMaterial3D', 'mat_water', albedo_color='Color(0.45, 0.7, 1, 1)', emission_enabled='true', emission='Color(0.2, 0.4, 0.8, 1)')
drop = sc.sub_res('SphereMesh', 'mesh_drop', material=water, radius=0.04, height=0.08)
soil_mesh = sc.sub_res('BoxMesh', 'mesh_soil', size=v3(2.1, 0.02, 1.3))
bed_shape = sc.sub_res('BoxShape3D', 'shape_bed', size=v3(2.3, 0.4, 1.5))
sc.node('PlotView', 'StaticBody3D', node_paths=['soil', 'plant', 'label', 'splash', 'approach'], collision_layer=2, collision_mask=0,
        script=sc.script('res://scenes/plantation/plot_view.gd'), soil='NodePath("Soil")', plant='NodePath("Plant")', label='NodePath("Label")',
        splash='NodePath("Splash")', stage_models=f'Array[PackedScene]([{", ".join(stage_ext)}])', plant_scale=1.0, approach='NodePath("Approach")')
sc.node('Shape', 'CollisionShape3D', '.', position=v3(0, 0.2, 0), shape=bed_shape)
sc.node('Bed', None, '.', instance=sc.scene('res://assets/models/plantation/raised_bed.glb'))
sc.node('Soil', 'MeshInstance3D', '.', position=v3(0, 0.31, 0), mesh=soil_mesh)
sc.node('Plant', 'Node3D', '.', position=v3(0, 0.3, 0))
sc.node('Lamp', None, '.', instance=sc.scene('res://assets/models/plantation/grow_lamp.glb'), **xform(1.6, 0, (0, 2.5, 0)))
sc.node('GrowLight', 'OmniLight3D', '.', position=v3(0, 2.3, 0), light_color='Color(0.949, 0.769, 0.42, 1)', light_energy=1.6, omni_range=4.5)
sc.node('Label', 'Label3D', '.', position=v3(0, 1.9, 0), pixel_size=0.008, billboard=1, no_depth_test='true', outline_modulate='Color(0, 0, 0, 1)', font_size=34, outline_size=10)
sc.node('Approach', 'Marker3D', '.', position=v3(0, 0, 1.3))
sc.node('Splash', 'CPUParticles3D', '.', position=v3(0, 1.4, 0), emitting='false', amount=60, lifetime=0.9, one_shot='true', explosiveness=0.6, mesh=drop,
        emission_shape=3, emission_box_extents=v3(1, 0.05, 0.5), direction=v3(0, -1, 0), spread=10.0, gravity=v3(0, -6, 0), initial_velocity_min=0.5, initial_velocity_max=1.5)
sc.write('scenes/plantation/plot_view.tscn')

# ======================================================================== field
# The estate. Manor and Lord Ashcombe in the north-west; the drive runs south to the main road; the wheat
# field lies far to the east with Jack's container on its eastern edge, reached by its own lane.
# Lanes meet the road on T-junction tiles, so the ruts join.
ROAD_Z = 44
ROAD_END = 83                    # road tile centres run along odd x from -83 to 83
MANOR_X, CONTAINER_X = -51, 61   # the two lanes leave the road at these tile centres
MANOR_LANE_END_Z, CONTAINER_LANE_END_Z = -20, 8

sc = Scene()
level = sc.script('res://scenes/common/level.gd')
env = sc.sub_res('Environment', 'env_field', background_mode=1, background_color='Color(0.431, 0.455, 0.502, 1)', ambient_light_source=2,
                 ambient_light_color='Color(0.369, 0.416, 0.478, 1)', ambient_light_energy=0.9, tonemap_mode=4, fog_enabled='true',
                 fog_light_color='Color(0.431, 0.455, 0.502, 1)', fog_density=0.006)
navmesh = sc.sub_res('NavigationMesh', 'navmesh_field', geometry_parsed_geometry_type=1, agent_radius=0.5, agent_height=1.5, agent_max_climb=0.25, geometry_collision_mask=3)
rain_mat = sc.sub_res('StandardMaterial3D', 'mat_rain', transparency=1, shading_mode=0, albedo_color='Color(0.85, 0.88, 0.9, 0.35)')
rain_mesh = sc.sub_res('BoxMesh', 'mesh_rain', material=rain_mat, size=v3(0.02, 0.55, 0.02))
rain_process = sc.sub_res('ParticleProcessMaterial', 'rain_process', emission_shape=3, emission_box_extents=v3(30, 1, 30), direction=v3(0.1, -1, 0),
                          spread=2.0, initial_velocity_min=18.0, initial_velocity_max=22.0, gravity=v3(0, -9.8, 0))
sc.node('Field', 'Node3D', node_paths=['nav_region', 'jack', 'camera_rig', 'hud', 'spawn_points'], script=level, nav_region='NodePath("NavRegion")',
        jack='NodePath("Jack")', camera_rig='NodePath("CameraRig")', hud='NodePath("Hud")', spawn_points='NodePath("SpawnPoints")')
sc.node('WorldEnvironment', 'WorldEnvironment', '.', environment=env)
sc.node('Sun', 'DirectionalLight3D', '.', rotation=v3(-0.9, 0.7, 0), shadow_enabled='true', directional_shadow_max_distance=90.0)
sc.node('DayNight', 'Node', '.', node_paths=['sun', 'world', 'rain'], script=sc.script('res://scenes/field/day_night.gd'),
        sun='NodePath("../Sun")', world='NodePath("../WorldEnvironment")', rain='NodePath("../CameraRig/Rain")')
sc.node('NavRegion', 'NavigationRegion3D', '.', navigation_mesh=navmesh)
NR = 'NavRegion'
static_box(sc, 'Ground', NR, (0, -0.5, 0), (172, 1, 132), mesh_mat='grass_mid')
row = sc.script('res://scenes/common/model_row.gd')
path_tile = sc.scene('res://assets/models/field/path_tile_2x2.glb')
junction_tile = sc.scene('res://assets/models/field/path_tile_t_2x2.glb')


def road_segment(name, x0, x1):
    sc.node(name, 'Node3D', NR, position=v3((x0 + x1) / 2, 0.005, ROAD_Z), script=row, model=path_tile, count=(x1 - x0) // 2 + 1,
            spacing=v3(2, 0, 0), vary_yaw='false', yaw_degrees=90.0)


def lane(name, x, z_end):
    first = ROAD_Z - 2
    sc.node(name, 'Node3D', NR, position=v3(x, 0.006, (first + z_end) / 2), script=row, model=path_tile, count=(first - z_end) // 2 + 1,
            spacing=v3(0, 0, 2), vary_yaw='false')


road_segment('RoadWest', -ROAD_END, MANOR_X - 2)
road_segment('Road', MANOR_X + 2, CONTAINER_X - 2)
road_segment('RoadEast', CONTAINER_X + 2, ROAD_END)
for node_name, x in [('JunctionManor', MANOR_X), ('JunctionContainer', CONTAINER_X)]:
    sc.node(node_name, None, NR, instance=junction_tile, position=v3(x, 0.005, ROAD_Z))
lane('DriveToManor', MANOR_X, MANOR_LANE_END_Z)
lane('PathToContainer', CONTAINER_X, CONTAINER_LANE_END_Z)
gravel = sc.sub_res('BoxMesh', 'mesh_forecourt', size=v3(31, 0.02, 11))
sc.node('Forecourt', 'MeshInstance3D', NR, position=v3(MANOR_X + 2.5, 0.008, -24.5), mesh=gravel, **{'surface_material_override/0': sc.material('gravel')})
yard = sc.sub_res('BoxMesh', 'mesh_yard', size=v3(13, 0.02, 7))
sc.node('ContainerYard', 'MeshInstance3D', NR, position=v3(CONTAINER_X + 3.5, 0.008, 8.5), mesh=yard, **{'surface_material_override/0': sc.material('path_dirt')})
puddle = sc.scene('res://assets/models/field/puddle.glb')
for i, (x, z) in enumerate([(-30, 43.4), (18, 44.6), (61.3, 28), (-51.2, 10)]):
    sc.node(f'Puddle{i}', None, NR, instance=puddle, **xform(1.0, 30 * i, (x, 0.012, z)))

# Wheat field: 43 x 58 m of standing wheat drawn as one MultiMesh.
sc.node('Crops', 'Node3D', NR, position=v3(35.5, 0, 2))
soil = sc.sub_res('BoxMesh', 'mesh_crop_soil', size=v3(43, 0.03, 58))
sc.node('Soil', 'MeshInstance3D', f'{NR}/Crops', position=v3(0, 0.015, 0), mesh=soil, **{'surface_material_override/0': sc.material('mud')})
sc.node('Wheat', 'MultiMeshInstance3D', f'{NR}/Crops', position=v3(0, 0.03, 0), script=sc.script('res://scenes/common/scatter_field.gd'),
        model=sc.scene('res://assets/models/field/wheat_clump.glb'), size='Vector2(42, 57)', spacing=1.15, jitter=0.3)
hedge_model = sc.scene('res://assets/models/field/hedge_2m.glb')
for node_name, (x, z), length in [('HedgeFieldNorth', (36, -28.5), 44), ('HedgeFieldSouth', (36, 32.5), 44), ('HedgeEstateNorth', (-40, -50), 80)]:
    hedge = static_box(sc, node_name, NR, (x, 0.8, z), (length, 1.6, 1.2))
    sc.node('Segments', 'Node3D', hedge, position=v3(0, -0.8, 0), script=row, model=hedge_model, count=length // 2, spacing=v3(2, 0, 0), vary_yaw='false')
bush = sc.scene('res://assets/models/field/bush.glb')
for node_name, (x, z), count, spacing in [('BushesForecourtWest', (-58.5, -18.6), 4, (2.4, 0, 0)), ('BushesForecourtEast', (-44, -18.6), 3, (2.4, 0, 0)),
                                          ('BushesFieldWest', (12.5, 2), 12, (0, 0, 4.6)), ('BushesYard', (69, 4), 4, (2.2, 0, 0))]:
    sc.node(node_name, 'Node3D', NR, position=v3(x, 0, z), script=row, model=bush, count=count, spacing=v3(*spacing))

# Ashcombe Hall, facing south over its forecourt.
manor = static_box(sc, 'Manor', NR, (MANOR_X, 0, -36), (26.6, 8, 11))
sc.node('Model', None, manor, instance=sc.scene('res://assets/models/field/manor.glb'))
label(sc, manor, 'Эшкомб-холл', 14.0, size=48)
cottage = static_box(sc, 'Cottage', NR, (20, 0, 54), (7.6, 6.7, 6.1))
sc.node('Model', None, cottage, instance=sc.scene('res://assets/models/field/cottage.glb'), **xform(1.0, 180))
round_tree = sc.scene('res://assets/models/field/tree_round.glb')
conifer = sc.scene('res://assets/models/field/tree_conifer.glb')
trees = [((-72, -40), round_tree, 1.5), ((-30, -44), conifer, 1.4), ((-70, -12), conifer, 1.3), ((-66, 18), round_tree, 1.4),
         ((-34, -8), round_tree, 1.6), ((-22, 20), conifer, 1.2), ((-12, -30), round_tree, 1.3), ((0, 4), conifer, 1.5),
         ((6, -40), round_tree, 1.4), ((-40, 30), round_tree, 1.2), ((70, -30), conifer, 1.4), ((74, 20), round_tree, 1.3),
         ((40, 52), conifer, 1.2), ((-60, 54), round_tree, 1.3), ((74, -8), round_tree, 1.2)]
for i, ((x, z), model, scale) in enumerate(trees):
    t = static_box(sc, f'Tree{i}', NR, (x, 0, z), (0.8, 3.0, 0.8))
    sc.node('Model', None, t, instance=model, **xform(scale, 37 * i))

# Jack's container on the far edge of the field; the parcel waits by its door.
container = static_box(sc, 'Container', NR, (CONTAINER_X, 0, 2), (2.44, 2.6, 6.0), layer=2, script=sc.script('res://scenes/field/container_entrance.gd'),
                       node_paths=['model', 'door', 'approach'],
                       extra={'model': 'NodePath("Model")', 'swing_door_names': 'PackedStringArray("DoorLeft", "DoorRight")',
                              'hide_when_open_names': 'PackedStringArray("GapGlow")', 'door': 'NodePath("Shelf")', 'door_open_offset': v3(0, 0, -1.4),
                              'destination': '"res://scenes/plantation/plantation.tscn"', 'destination_spawn': '"from_elevator"', 'approach': 'NodePath("Approach")',
                              'hover_label': '"Контейнер — спуститься на плантацию"'})
sc.node('Model', None, container, instance=sc.scene('res://assets/models/field/container.glb'), **xform(1.0, -90))
sc.node('Shelf', None, container, instance=sc.scene('res://assets/models/field/container_shelf.glb'), **xform(1.0, 0, (0, 0, 2.6)))
label(sc, container, 'Контейнер', 3.4, size=44)
sc.node('Approach', 'Marker3D', container, position=v3(0, 0, 4.4))
parcel = f'{NR}/Parcel'
sc.node('Parcel', 'StaticBody3D', NR, node_paths=['visual', 'approach'], position=v3(CONTAINER_X + 2.4, 0, 6.2), collision_layer=0, collision_mask=0,
        script=sc.script('res://scenes/field/parcel_box.gd'), visual='NodePath("Visual")', approach='NodePath("Approach")')
sc.node('Shape', 'CollisionShape3D', parcel, position=v3(0, 0.4, 0), shape=sc.sub_res('BoxShape3D', 'shape_parcel', size=v3(1.4, 0.8, 1.0)))
sc.node('Visual', 'Node3D', parcel, visible='false')
sc.node('Crate', None, f'{parcel}/Visual', instance=sc.scene('res://assets/models/field/stash_crate.glb'), **xform(1.6))
label(sc, f'{parcel}/Visual', 'Посылка', 1.4, color='Color(0.96, 0.84, 0.45, 1)')
sc.node('Approach', 'Marker3D', parcel, position=v3(-0.6, 0, 1.3))

# Land Rovers: one at the manor, one at the container. Parking spots know their way to the main road.
sc.node('Parking', 'Node3D', '.')
spot_script = sc.script('res://scenes/field/parking_spot.gd')
spots = [('Manor', 'к усадьбе', (-38.5, 0, -22), 0, (3.2, 0, 0), (MANOR_X, 0, MANOR_LANE_END_Z), (MANOR_X, 0, ROAD_Z)),
         ('Container', 'к контейнеру', (CONTAINER_X + 5.5, 0, 9.5), 0, (3.2, 0, 0), (CONTAINER_X, 0, CONTAINER_LANE_END_Z + 2), (CONTAINER_X, 0, ROAD_Z)),
         ('Road', 'на дорогу', (2, 0, 41.3), -90, (0, 0, 5.5), (5, 0, 42.2), (8, 0, ROAD_Z))]
for spot_name, title, pos, yaw, bay_offset, lane_end, junction in spots:
    sc.node(f'{spot_name}LaneEnd', 'Marker3D', 'Parking', position=v3(*lane_end))
    sc.node(f'{spot_name}Junction', 'Marker3D', 'Parking', position=v3(*junction))
    sc.node(spot_name, 'Marker3D', 'Parking', node_paths=['lane_end', 'junction'], script=spot_script, title=f'"{title}"',
            lane_end=f'NodePath("../{spot_name}LaneEnd")', junction=f'NodePath("../{spot_name}Junction")', bay_offset=v3(*bay_offset), **xform(1.0, yaw, pos))
rover_script = sc.script('res://scenes/field/land_rover.gd')
rover_model = sc.scene('res://assets/models/field/land_rover.glb')
for rover_name, spot_name in [('RoverManor', 'Manor'), ('RoverContainer', 'Container')]:
    rover = static_box(sc, rover_name, NR, (0, 0, 0), (2.0, 2.0, 4.4), layer=4, script=rover_script, node_paths=['parking', 'spot', 'approach'],
                       extra={'parking': 'NodePath("../../Parking")', 'spot': f'NodePath("../../Parking/{spot_name}")', 'approach': 'NodePath("Approach")'})
    sc.node('Model', None, rover, instance=rover_model)
    sc.node('Approach', 'Marker3D', rover, position=v3(-1.9, 0, 0.4))

person_shape = sc.sub_res('CapsuleShape3D', 'shape_person', radius=0.35, height=1.8)
candidate_script = sc.script('res://scenes/field/worker_candidate.gd')
farmhand = sc.scene('res://scenes/actors/farmhand.tscn')
for node_name, worker_id, title, x in [('Candidate', 'tom', 'Том', -59.0), ('CandidateDave', 'dave', 'Дейв', -57.0), ('CandidateBarry', 'barry', 'Барри', -55.0)]:
    c = f'{NR}/{node_name}'
    sc.node(node_name, 'StaticBody3D', NR, node_paths=['visual', 'leave_target', 'approach'], position=v3(x, 0, -21.0), collision_layer=2, collision_mask=0,
            script=candidate_script, worker_id=f'"{worker_id}"', visual='NodePath("Visual")', leave_target='NodePath("../Container/Approach")',
            walker_scene=farmhand, approach='NodePath("Approach")')
    sc.node('Shape', 'CollisionShape3D', c, position=v3(0, 0.9, 0), shape=person_shape)
    sc.node('Visual', 'Node3D', c)
    person(sc, f'{c}/Visual', 'res://assets/models/characters/worker.glb')
    label(sc, f'{c}/Visual', title, 2.3)
    sc.node('Approach', 'Marker3D', c, position=v3(0, 0, -1.5))
lord = f'{NR}/Lord'
sc.node('Lord', 'StaticBody3D', NR, node_paths=['approach'], position=v3(MANOR_X + 2, 0, -27.0), collision_layer=2, collision_mask=0,
        script=sc.script('res://scenes/field/lord_ashcombe.gd'), approach='NodePath("Approach")')
sc.node('Shape', 'CollisionShape3D', lord, position=v3(0, 0.9, 0), shape=person_shape)
person(sc, lord, 'res://assets/models/characters/inspector.glb')
label(sc, lord, 'Лорд Эшкомб', 2.3, color='Color(0.96, 0.84, 0.45, 1)')
sc.node('Approach', 'Marker3D', lord, position=v3(0, 0, 1.5))
sc.node('PorchLight', 'OmniLight3D', lord, position=v3(-2, 3.2, -1.8), light_color='Color(0.949, 0.769, 0.42, 1)', light_energy=1.6, omni_range=7.0)
gang = f'{NR}/Raiders'
sc.node('Raiders', 'StaticBody3D', NR, node_paths=['visual', 'approach'], position=v3(CONTAINER_X + 3.5, 0, 13), collision_layer=0, collision_mask=0,
        script=sc.script('res://scenes/field/raider_gang.gd'), visual='NodePath("Visual")', approach='NodePath("Approach")')
sc.node('Shape', 'CollisionShape3D', gang, position=v3(0, 0.9, 0), shape=person_shape)
sc.node('Visual', 'Node3D', gang, visible='false')
for index, (dx, yaw) in enumerate([(-0.5, 200), (0.6, 160)]):
    sc.node(f'Model{index}', 'Node3D', f'{gang}/Visual', **xform(1.0, yaw, (dx, 0, 0)), script=sc.script('res://scenes/common/character_model.gd'))
    sc.node('Mesh', None, f'{gang}/Visual/Model{index}', instance=sc.scene('res://assets/models/characters/courier.glb'))
label(sc, f'{gang}/Visual', 'Гопники', 2.3, color='Color(1, 0.55, 0.45, 1)')
sc.node('Approach', 'Marker3D', gang, position=v3(-1.4, 0, 1.4))

# Walking routes along the roads: the inspector comes in from the east, couriers head out west.
route_script = sc.script('res://scenes/common/road_route.gd')
sc.node('Routes', 'Node3D', '.')
for route_name, points in [('InspectorWay', [(ROAD_END + 1, 0, ROAD_Z), (CONTAINER_X, 0, ROAD_Z), (CONTAINER_X, 0, 6.6)]),
                           ('CourierWay', [(CONTAINER_X - 1.6, 0, 7.0), (CONTAINER_X, 0, 10), (CONTAINER_X, 0, ROAD_Z), (-ROAD_END - 1, 0, ROAD_Z)])]:
    sc.node(route_name, 'Node3D', 'Routes', script=route_script)
    for index, point in enumerate(points):
        sc.node(f'P{index}', 'Marker3D', f'Routes/{route_name}', position=v3(*point))
sc.node('CourierIdle', 'Marker3D', 'Routes', **xform(1.0, 90, (CONTAINER_X - 2.6, 0, 6.6)))
sc.node('Inspector', 'Node3D', '.', node_paths=['route', 'model'], visible='false', script=sc.script('res://scenes/field/inspector_view.gd'),
        route='NodePath("../Routes/InspectorWay")', model='NodePath("Model")')
person(sc, 'Inspector', 'res://assets/models/characters/inspector.glb')
for node_name, slot in [('CourierA', 0), ('CourierB', 1)]:
    sc.node(node_name, 'Node3D', '.', node_paths=['depot_point', 'route', 'model', 'name_label'], visible='false', script=sc.script('res://scenes/field/courier_view.gd'),
            slot=slot, depot_point='NodePath("../Routes/CourierIdle")', route='NodePath("../Routes/CourierWay")', model='NodePath("Model")', name_label='NodePath("Label")')
    person(sc, node_name, 'res://assets/models/characters/courier.glb')
    sc.node('Label', 'Label3D', node_name, position=v3(0, 2.3, 0), pixel_size=0.008, billboard=1, no_depth_test='true', font_size=32, outline_size=10)
sc.node('Jack', None, '.', instance=sc.scene('res://scenes/actors/jack.tscn'))
sc.node('CameraRig', 'Node3D', '.', node_paths=['camera'], rotation=v3(0, 0.785398, 0), script=sc.script('res://scenes/common/iso_camera_rig.gd'),
        camera='NodePath("Camera")', distance=36.0, bounds='Rect2(-80, -52, 160, 110)')
sc.node('Camera', 'Camera3D', 'CameraRig')
sc.node('Rain', 'GPUParticles3D', 'CameraRig', position=v3(0, 18, 0), amount=2500, lifetime=1.3, visibility_aabb='AABB(-35, -25, -35, 70, 30, 70)',
        process_material=rain_process, draw_pass_1=rain_mesh)
sc.node('SpawnPoints', 'Node3D', '.')
for node_name, pos in [('start', (MANOR_X + 3.5, 0, -25)), ('from_elevator', (CONTAINER_X, 0, 7.6)),
                       ('road_west', (-ROAD_END, 0, ROAD_Z)), ('road_east', (ROAD_END, 0, ROAD_Z))]:
    sc.node(node_name, 'Marker3D', 'SpawnPoints', position=v3(*pos))
sc.node('Hud', None, '.', instance=sc.scene('res://scenes/ui/hud.tscn'))
sc.write('scenes/field/field.tscn')

# ======================================================================== plantation
sc = Scene()
env = sc.sub_res('Environment', 'env_bunker', background_mode=1, background_color='Color(0.08, 0.07, 0.06, 1)', ambient_light_source=2,
                 ambient_light_color='Color(0.29, 0.263, 0.235, 1)', ambient_light_energy=1.4, tonemap_mode=4, glow_enabled='true', glow_intensity=0.6)
navmesh = sc.sub_res('NavigationMesh', 'navmesh_bunker', geometry_parsed_geometry_type=1, agent_radius=0.5, agent_height=1.5, agent_max_climb=0.25, geometry_collision_mask=3)
sc.node('Plantation', 'Node3D', node_paths=['nav_region', 'jack', 'camera_rig', 'hud', 'spawn_points'], script=sc.script('res://scenes/common/level.gd'),
        nav_region='NodePath("NavRegion")', jack='NodePath("Jack")', camera_rig='NodePath("CameraRig")', hud='NodePath("Hud")', spawn_points='NodePath("SpawnPoints")',
        default_spawn='"from_elevator"')
sc.node('WorldEnvironment', 'WorldEnvironment', '.', environment=env)
sc.node('NavRegion', 'NavigationRegion3D', '.', navigation_mesh=navmesh)
static_box(sc, 'Floor', NR, (0, -0.5, 0), (20, 1, 14), mesh_mat='concrete')
static_box(sc, 'WallNorth', NR, (0, 1.5, -7.25), (21, 3, 0.5))
static_box(sc, 'WallWest', NR, (-10.25, 1.5, 0), (0.5, 3, 14))
static_box(sc, 'CurbSouth', NR, (0, 0.25, 7.25), (21, 0.5, 0.5), mesh_mat='concrete_dark')
static_box(sc, 'CurbEast', NR, (10.25, 0.25, 0), (0.5, 0.5, 14), mesh_mat='concrete_dark')
wall = sc.scene('res://assets/models/plantation/concrete_wall_2m.glb')
sc.node('WallNorthSegments', 'Node3D', NR, position=v3(0, 0, -7.12), script=sc.script('res://scenes/common/model_row.gd'), model=wall, count=10, spacing=v3(2, 0, 0), vary_yaw='false')
sc.node('WallWestSegments', 'Node3D', NR, position=v3(-10.12, 0, 0), script=sc.script('res://scenes/common/model_row.gd'), model=wall, count=7, spacing=v3(0, 0, 2), vary_yaw='false', yaw_degrees=90.0)
sc.node('Vents', 'Node3D', NR, position=v3(1, 2.3, -6.55), script=sc.script('res://scenes/common/model_row.gd'), model=sc.scene('res://assets/models/plantation/vent_duct_2m.glb'),
        count=8, spacing=v3(2, 0, 0), vary_yaw='false')
elevator = static_box(sc, 'Elevator', NR, (-8.5, 0, 0), (2.2, 2.8, 2.4), layer=2, script=sc.script('res://scenes/common/elevator.gd'),
                      node_paths=['model', 'approach'],
                      extra={'model': 'NodePath("Model")', 'model_door_name': '"Door"', 'door_open_offset': v3(1.84, 0, 0),
                             'destination': '"res://scenes/field/field.tscn"', 'destination_spawn': '"from_elevator"', 'approach': 'NodePath("Approach")',
                             'hover_label': '"Лифт — подняться в контейнер"'})
sc.node('Model', None, elevator, instance=sc.scene('res://assets/models/plantation/lift_cage.glb'), **xform(1.0, 90))
label(sc, elevator, 'Лифт', 3.9, size=44)
sc.node('Approach', 'Marker3D', elevator, position=v3(2.1, 0, 0))
desk_size = (1.2, 0.85, 1.6)
desk = static_box(sc, 'Computer', NR, (-8.9, 0, 3.8), desk_size, layer=2, mesh_mat='oak', script=sc.script('res://scenes/plantation/computer_desk.gd'),
                  node_paths=['screen_glow', 'approach'], extra={'screen_glow': 'NodePath("Glow")', 'approach': 'NodePath("Approach")'})
monitor = sc.sub_res('BoxMesh', 'mesh_monitor', size=v3(0.12, 0.55, 0.8))
screen = sc.sub_res('BoxMesh', 'mesh_screen', size=v3(0.02, 0.45, 0.7))
sc.node('Monitor', 'MeshInstance3D', desk, position=v3(-0.1, 1.15, 0), mesh=monitor, **{'surface_material_override/0': sc.material('pot_black')})
sc.node('Glow', 'MeshInstance3D', desk, position=v3(-0.03, 1.15, 0), mesh=screen, **{'surface_material_override/0': sc.material('police_blue', emission=True)})
label(sc, desk, 'Компьютер', 2.0)
sc.node('Approach', 'Marker3D', desk, position=v3(1.5, 0, 0))
bench = static_box(sc, 'Bench', NR, (-8.9, 0, -3.8), desk_size, layer=2, mesh_mat='timber', script=sc.script('res://scenes/plantation/packing_bench.gd'),
                   node_paths=['pile', 'progress_label', 'approach'], extra={'pile': 'NodePath("Pile")', 'progress_label': 'NodePath("Label")', 'approach': 'NodePath("Approach")'})
heap = sc.scene('res://assets/models/plantation/harvest_pile.glb')
sc.node('Pile', 'Node3D', bench, visible='false', position=v3(0, 0.85, 0))
for i, (x, z, yaw) in enumerate([(0.05, 0.0, 0), (-0.1, -0.45, 70), (0.1, 0.45, 140)]):
    sc.node(f'Heap{i}', None, f'{bench}/Pile', instance=heap, **xform(1.0 if i == 0 else 0.8, yaw, (x, 0, z)))
label(sc, bench, 'Стол фасовки', 2.0)
sc.node('Approach', 'Marker3D', bench, position=v3(1.5, 0, 0))
shelf = static_box(sc, 'Shelf', NR, (-8.2, 0, -6.4), (2.0, 2.1, 0.6))
frame = sc.sub_res('BoxMesh', 'mesh_shelf_frame', size=v3(2.0, 2.1, 0.08))
plank = sc.sub_res('BoxMesh', 'mesh_shelf_plank', size=v3(1.9, 0.05, 0.45))
sc.node('Back', 'MeshInstance3D', shelf, position=v3(0, 1.05, -0.25), mesh=frame, **{'surface_material_override/0': sc.material('oak')})
for i, y in enumerate([0.05, 0.67, 1.29]):
    sc.node(f'Plank{i}', 'MeshInstance3D', shelf, position=v3(0, y, 0), mesh=plank, **{'surface_material_override/0': sc.material('oak')})
sc.node('Stock', 'Node3D', shelf, node_paths=['label'], script=sc.script('res://scenes/plantation/stock_shelf.gd'),
        box_scene=sc.scene('res://assets/models/field/stash_crate.glb'), box_scale=0.55, label='NodePath("Label")')
label(sc, f'{shelf}/Stock', 'Склад', 2.5)
sc.node('PlotsGrid', 'Node3D', NR, position=v3(1.5, 0, 0), script=sc.script('res://scenes/plantation/plots_grid.gd'), plot_scene=sc.scene('res://scenes/plantation/plot_view.tscn'))
sc.node('ElevatorLight', 'OmniLight3D', '.', position=v3(-6.5, 2.6, 0), light_color='Color(0.949, 0.769, 0.42, 1)', light_energy=1.2, omni_range=6.0)
for node_name, z in [('DeskLight', 4.0), ('BenchLight', -4.8)]:
    sc.node(node_name, 'OmniLight3D', '.', position=v3(-7.6, 2.6, z), light_color='Color(0.949, 0.769, 0.42, 1)', light_energy=1.0, omni_range=5.0)
sc.node('Jack', None, '.', instance=sc.scene('res://scenes/actors/jack.tscn'))
sc.node('Worker', None, '.', instance=sc.scene('res://scenes/actors/worker.tscn'), node_paths=['plots_grid', 'idle_spot', 'arrival_spot'],
        plots_grid='NodePath("../NavRegion/PlotsGrid")', idle_spot='NodePath("../SpawnPoints/worker_idle")', arrival_spot='NodePath("../SpawnPoints/from_elevator")')
sc.node('CameraRig', 'Node3D', '.', node_paths=['camera'], rotation=v3(0, 0.785398, 0), script=sc.script('res://scenes/common/iso_camera_rig.gd'),
        camera='NodePath("Camera")', distance=30.0, zoom_min=14.0, zoom_max=50.0, bounds='Rect2(-9, -7, 18, 14)')
sc.node('Camera', 'Camera3D', 'CameraRig')
sc.node('SpawnPoints', 'Node3D', '.')
for node_name, pos in [('from_elevator', (-6.2, 0, 0.8)), ('worker_idle', (-6, 0, -3.5))]:
    sc.node(node_name, 'Marker3D', 'SpawnPoints', position=v3(*pos))
sc.node('Hud', None, '.', instance=sc.scene('res://scenes/ui/hud.tscn'))
sc.write('scenes/plantation/plantation.tscn')
print('ok')

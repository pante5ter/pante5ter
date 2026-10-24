# tools/blender — генерация моделей Old Money

Low-poly модели по STYLE.md, собранные скриптами bpy (Blender 5.2). Каждая грань модели
UV-шится в центр одной клетки `res://assets/textures/palette_atlas.png`, других текстур нет.
Скрипты перезаписывают свои .glb и превью при каждом запуске.

## Запуск

Blender не в PATH. Запускать из корня репозитория:

```bash
"D:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python-exit-code 1 --python tools/blender/make_field.py
```

```bash
"D:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python-exit-code 1 --python tools/blender/make_plantation.py
```

```bash
"D:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python-exit-code 1 --python tools/blender/make_characters.py
```

```bash
"D:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python-exit-code 1 --python tools/blender/make_estate.py
```

Каждый скрипт печатает строки `MODEL <путь> tris <N> <бюджет> ok|OUT OF BUDGET size(x,y,z)`
и в конце `ALL OK`. Если модель вышла за бюджет STYLE.md §3, скрипт завершается с кодом 1.
Около минуты на скрипт, большая часть — рендер превью в EEVEE.

## Файлы

| Скрипт | Что делает | Выход |
| --- | --- | --- |
| `om_common.py` | палитра из palette.json, два материала, примитивы (box, tube, loft, prism, leaf_star…), экспорт .glb, подсчёт треугольников, превью-рендер | — (модуль) |
| `make_field.py` | поле | `assets/models/field/*.glb`, `previews/field.png` |
| `make_plantation.py` | подземная плантация | `assets/models/plantation/*.glb`, `previews/plantation.png` |
| `make_characters.py` | четыре персонажа | `assets/models/characters/*.glb`, `previews/characters.png` |
| `make_estate.py` | поместье: усадьба, Лендровер, пшеница, куст, Т-перекрёсток дорожки, куча урожая | `assets/models/field/*.glb`, `assets/models/plantation/harvest_pile.glb`, `previews/estate.png` |

`previews/` содержит `.gdignore`, Godot её не импортирует.

## Модели

Оси: 1 единица = 1 м, пивот в центре основания, перед модели смотрит в **+Z Godot**
(в Blender −Y). Треугольники — на момент последнего прогона.

### field/
| Файл | Треуг. | Бюджет | Размер (x × y × z в Godot: ширина × высота × глубина) | Отдельные узлы |
| --- | --- | --- | --- | --- |
| container.glb | 1134 | постройка 500–2000 | 6.0 × 2.6 × 2.44, дверной торец на +X | `DoorLeft`, `DoorRight` (пивот на петле, вращать вокруг локальной Y), `GapGlow` (тёплая щель между створками, emissive; скрыть, когда двери открыты) |
| container_shelf.glb | 456 | реквизит 50–500 | 1.8 × 2.1 × 0.5 | — |
| hedge_2m.glb | 56 | реквизит | 2.0 × 1.32 × 0.94, сегменты стыкуются по X | — |
| tree_conifer.glb | 76 | реквизит | 2.3 × 4.7 | — |
| tree_round.glb | 212 | реквизит | 2.6 × 3.75 | — |
| path_tile_2x2.glb | 124 | реквизит | 2 × 2, толщина 3 см; колеи идут вдоль Z | — |
| puddle.glb | 104 | реквизит | 1.6 × 1.0 | `Water` — поверхность воды, ей мокрый материал (roughness 0.35) |
| cottage.glb | 1320 | постройка | 7.6 × 6.7 × 6.1 | `WindowsGlow` — светящиеся стёкла (lamp_warm); без него видно тёмное стекло |
| stash_crate.glb | 264 | реквизит | 0.77 × 0.44 × 0.49 (с ручками) | `Lid` — пивот на заднем верхнем ребре, открывать вращением вокруг локальной X |

### field/ — make_estate.py
| Файл | Треуг. | Бюджет | Размер (x × y × z) | Отдельные узлы |
| --- | --- | --- | --- | --- |
| manor.glb | 972 | постройка | 26.6 × 12.9 × 11.2, фасад с портиком на +Z | `WindowsGlow` — светящиеся окна (lamp_warm) |
| land_rover.glb | 408 | реквизит | 2.1 × 2.0 × 4.5, капот на +Z | — |
| wheat_clump.glb | 86 | растение | 0.9 × 1.0 × 0.9, для MultiMesh | — |
| bush.glb | 100 | реквизит | 1.6 × 1.3 × 1.5 | — |
| path_tile_t_2x2.glb | 120 | реквизит | 2 × 2; колеи вдоль X, ответвление к −Z стыкуется с path_tile_2x2 | — |
| plantation/harvest_pile.glb | 80 | растение | 0.74 × 0.32 × 0.70, куча нефасованного урожая | — |

### plantation/
| Файл | Треуг. | Бюджет | Размер | Отдельные узлы |
| --- | --- | --- | --- | --- |
| raised_bed.glb | 252 | реквизит | 2.3 × 0.35 × 1.5 | `Soil` — грунт, верх на высоте **0.30 м** (на него ставить растения) |
| plant_stage_1.glb | 32 | растение 30–150 | высота 0.12 | — |
| plant_stage_2.glb | 60 | растение | 0.38 | — |
| plant_stage_3.glb | 108 | растение | 0.78 | — |
| plant_stage_4.glb | 116 | растение | 1.09, почки hay/wheat | — |
| grow_lamp.glb | 108 | реквизит | 1.2 м планка; пивот = низ светящейся полосы, тяги 0.8 м вверх до потолочных пластин | — (полоса lamp_warm на emissive-материале) |
| vent_duct_2m.glb | 168 | реквизит | 2.0 вдоль X, 0.5 × 0.4; пивот = низ короба, хомуты 0.35 м вверх | — |
| concrete_wall_2m.glb | 144 | реквизит | 2.0 × 3.0 × 0.25, стыкуется по X, кабель-канал сквозной | — |
| lift_cage.glb | 800 | постройка | 2 × 2, пол 0.12 м, рама 2.5 м, трос до 3.7 м | `Door` — решётчатая дверь спереди; пивот в левом нижнем углу: сдвигать по локальной X (на 1.84 м) или вращать вокруг Y |

### characters/
| Файл | Треуг. | Рост | Цвета |
| --- | --- | --- | --- |
| jack.glb | 732 | 1.80 | camel_coat (длинное распахнутое пальто) поверх navy_suit, без шляпы |
| worker.glb | 764 | 1.74 | tweed_green пиджак, кепка cap_grey |
| courier.glb | 736 | 1.76 | charcoal пальто до колена, сумка через плечо |
| inspector.glb | 812 | 1.72 | tweed_brown, широкие плечи, плоская кепка, планшет, галстук tie_burgundy |

Персонажи — один статичный меш, A-поза, без скелета (первый проход).

## Подключение в Godot

1. **Атлас и материалы.** Картинка в .glb не вшита: `om_common.link_shared_atlas` после экспорта
   заменяет её ссылкой `../../textures/palette_atlas.png`, так что все модели берут общий
   `res://assets/textures/palette_atlas.png` и Godot не создаёт копий рядом с моделями.
   В каждом .glb два материала по имени: `om_palette` и (если есть свечение) `om_palette_emissive`.
   Готовые общие версии для тонкой настройки (roughness 0.9, NEAREST, энергия свечения 2.0) —
   `res://assets/models/materials/om_palette.tres` и `om_palette_emissive.tres`; подключаются через
   Advanced Import → Materials → Use External. Файлы .tres написаны вручную, Godot их ещё не
   открывал — проверь при первом импорте.
2. **Свечение днём/ночью.** Энергию окон, щели контейнера и ламп меняй на общем emissive-материале
   или прячь узлы `WindowsGlow` / `GapGlow`.
3. **Лужа.** Узлу `Water` поставь мокрый вариант материала (roughness 0.35, STYLE §2).
4. **Ориентация.** Перед модели = +Z. `look_at(target, Vector3.UP, true)` (use_model_front)
   поворачивает модель лицом к цели.

## Как добавить модель

Функция `make_<имя>(p)` строит `om.Mesh(p, "<имя>")`, добавляет примитивы с цветом по имени
клетки из palette.json (или словарём по направлению грани: `top/bottom/front/back/left/right/side/all`)
и возвращает `m.finish()`. Подвижные части — отдельный `om.Mesh(...).finish(parent=root, location=pivot)`.
Добавь её в список `MODELS` скрипта с бюджетом `prop|building|character|plant`.

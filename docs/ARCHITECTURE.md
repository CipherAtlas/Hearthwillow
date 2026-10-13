# Architecture and source mapping

[Documentation index](../README.md) · [Status/backlog](../MILESTONE.md)

## Runtime structure

`project.godot` runs `scenes/main.tscn`. Static scenery/UI/lights/imported models
are saved nodes/resources; GDScript owns behavior. Runtime loads native converted
resources directly, without Three.js, the web app, a converter server or Worker.

| Scene/node | Responsibility | Behavior under `scenes/` |
| --- | --- | --- |
| `main.tscn` | Composition, environment, audio players, map/HUD and connections | System scripts below |
| `Village` → `village.tscn` | Batched scenery, static collision, Actors | `village_actor.gd` |
| `Player` → `player.tscn` | Spirit and CharacterBody movement, horse mount/dismount | `player.gd` |
| `WorldSurface` | Placements, terrain/bridge floors, obstacle/water queries, contact surfaces, recovery | `world_surface.gd` |
| `CameraRig` | Smoothed follow/orbit/zoom and obstruction recovery | `camera.gd` |
| `VillageLife` | Local navigation/engagement, animal actions, dog cards and forage | `village_life.gd` |
| `HUD/Speech` | Head-anchored overlays, visibility and nearby buttons | `village_dialogue.gd` |
| `VillageFlock` | Native source dove parts, flight/landing/crumbs and meal phases | `village_flock.gd` |
| `VillageSound` | Native players, mix, spatial ambience, crossfades and cues | `village_sound.gd` |
| `VillageLighting` → `village_lighting.tscn` | Saved lantern halos/point lights/hearth; cached spirit, glass, coal and water weather updates; two closest lamps at 10 Hz | `village_lighting.gd` |
| `HUD/Menus` → `menus.tscn` | Starter/guide/settings/inventory, rebinding, language/weather/graphics and blocking | `village_menus.gd` |
| `HUD/VillageMap` | Cached original landscape, 17 fixed destinations, mini/expanded fit/zoom/pan and travel; visitor on separate CanvasItem | `village_map.gd`, `map_visitor.gd` |
| `VillageActivities` → `activities.tscn` | Crops/forage/gifts/cooking/dishes, garden UI and saves | `village_activities.gd`, `growth_clock.gd`, `growth_clock_ui.gd` |
| `VillageSeating` → `seating.tscn` | Seat slots, pointer picking, picnic/bird actions, pendulum swings | `village_seating.gd` |
| `VillageRace` → `race.tscn` | Invitation/countdown/gates/rival/results/cancel | `village_race.gd` |
| `FocusCottage` → `focus_cottage.tscn` | Private room/camera/window, timer, desk effects, cat UI | `focus_cottage.gd`, `cottage_cat.gd` |
| `QuietPlaces` → `quiet_places.tscn` | Journal/kind notes/breathing, hearth music, tea, birds/garden staging, source camera/poses and entry/exit | `quiet_places.gd`, `village_journal.gd`, `breath_orbit.gd` |
| `PondLife` → `pond_life.tscn` | Native swan/duck-family/fish motion; dock feeding panel/input, shared meal/status, hearts/ripples/crumbs and reply anchors | `pond_life.gd` |
| `TowerLookout` → `tower_lookout.tscn` | Source platform bounds, first-person walking/look and return to entrance | `tower_lookout.gd` |
| `ReleaseBenchmark` | Opt-in 16-scenario native release frame-time harness | `release_benchmark.gd` |

The map's saved Paper/Terrain/Landscape/Visitor/Expanded nodes remain editable in
main.tscn. Terrain clips the landscape; its TextureRect does not regenerate draw
commands on an idle timer. Destination buttons/captions are cached once and reflow
on view, selection or language changes. Only the visitor's position and heading
are sampled during play; actor simulation is never queried by the map.

## Original-source references

VillageMenus passes its eased weather blend to VillageLighting. The latter caches
materials once, updates only meaningful weather changes, and restores each
spirit's original day color/emission. Window emission also uses the original
painted window texture. Lamp lights stay shadow-free, affect outdoor layer 1 and
activate only the two nearest fixtures; all lantern halos remain visible at night.
Saved fixture placement comes from extracted glass geometry and authored layout
transforms, without reconstructing or replacing village.tscn. Water and the lower
directional fill now follow the same dusk/night transition. Hearth/coal flicker
continues independently of weather.

Walking and riding share the existing contact player and Effects/Master mix.
Walking/takeoff/landing gain is 0.25; hoof gain is 0.18. Riding uses sixteen
source horseAudio.ts cues, and source strides 1.8 / 2.9 / 3.8 multiplied by the
horse's Z scale. Contacts are limited to one every 0.22 seconds and suppressed
while idle, in blocking UI or activity poses. Mount/dismount resets accumulated
contact distance. No new audio dependency or user preference migration is needed.

Paths below are relative to `/Users/sabar/Documents/cosy-v1/features/village/`.
Read source behavior before adding parity features; scenery is not a state machine.

| Native area | Source starting points |
| --- | --- |
| World/layout | `VillageEngine.ts`, `sceneLayout.ts`, `townScene.ts` |
| Environment | `environment.ts`, `atmosphere.ts`, `flame.ts`, world builders |
| Residents/animals | `villagers.ts`, `townAnimals.ts`, `dialogue.ts`, `companionWalk.ts` |
| Horses/race | `horses.ts`, `horseRiding.ts`, `horseMotion.ts`, `HorseControls.tsx`, `TownActivityHUD.tsx` |
| Map/menu/keys | `VillageMap.tsx`, `mapDestinations.ts`, `VillageMenus.tsx`, `KeybindingControls.tsx`, `village.css` |
| Crops/kitchen/picnic | `garden.ts`, `gardenScene.ts`, `gardenGrowthDisplay.ts`, `gardenKitchenScene.ts`, `picnic.ts`, `picnicScene.ts`, `GardenActivities.tsx` |
| Cottage/cat/timer | `focusCottageScene.ts`, `focusCottageProps.ts`, `cottageCat.ts`, `useSession.ts`, `Activities.tsx` |
| Writing / kind notes / breathing | `Activities.tsx`, `activityScene.ts`, `sharedActors.ts`, `villageCamera.ts`; `features/gratitude/storage.ts` |
| Pond | `pondLife.ts`, `gardenScene.ts`, `GardenActivities.tsx`, `garden.ts`, `animalDialogue.ts`; Worker feed validation is mapped to local checks |
| Sound | `audio.ts`, `soundtrack.ts`, `horseAudio.ts`, `townAnimalAudio.ts`; source recordings under `public/village/` |

## Standardized placement and surface rules

`assets/village/world-data.json` supplies item placements, paths/rivers/colliders,
actors and bridge patch metadata. WorldSurface groups items by asset and owns
`world_point`, `local_point`, `item_transform`, route distance/closest point,
`floor_at`, `can_enter`, `clear_at`, contact surfaces and safe recovery.

Terrain uses `floor-heights.bin`; bridges use four sampled patches. Rivers use
saved spine/width data with an eight-unit spatial index. Rotated/scaled ponds,
docks and obstacles are evaluated in their placement frame. Map destinations,
race locations and activity anchors reuse these common rules.

Standardization is not complete: flock clearing, restoration anchors and some
scenery-specific constants remain fixed. A layout change must update/check saved
render geometry, surface data, navigation, map and interaction anchors together.
Changing a map marker alone does not move geometry. Runtime helpers do not rebuild
visual paths/rivers when metadata changes.

## Input and activity transitions

Use InputMap actions from `project.godot`. `interaction_button.gd` and shared
interaction theme/keycap resources connect pointer and keyboard operations.
Shared held controls release on pointer-up, hiding and tree exit. Seating also
explicitly releases holds on application focus loss; other contexts still need
that lifecycle review. Do not hide/re-show an unchanged button during refresh
while the user is pressing it.

`VillageMenus.sync_blocking()` coordinates UI blocking and mouse capture.
Entering gameplay and closing map/settings/sound/inventory restore capture.
CameraRig records an explicit Escape release so ordinary HUD synchronization does
not capture it again; clicking the world clears that release. Private cottage and
quiet interfaces retain a pointer. Seats/races preserve gameplay capture, and the
seat handler records Escape before consuming it to leave. Window focus gain
rechecks this policy without overriding an explicit release.

 Player `activity_locked`
protects seat/cottage poses; `race_countdown` freezes the starting horse. Seating
owns its nearby/occupied context so unrelated cards do not compete. Map travel
releases activities, cancels races and dismounts. QuietPlaces locks movement and uses its saved camera; map travel releases it
before entering another destination. Journal input bypasses menu/game shortcut
letters, retains Cmd/Ctrl+Enter and IME composition protection, and leaves on
Escape. Pond feeding uses the shared nearest-animal cream bubble, projected with
the currently active camera and kept clear of activity panels.

Swings and picnic cushions choose forward/reverse from the approach side. T /
Turn around keeps the same seat/angle/speed, changes the avatar and eased camera
side, clears pointer pumping holds and makes W/S pump relative to facing. Backed
benches retain their authored direction. Picnic access is permitted while the
seated player is locked; unrelated ritual contexts remain excluded.

Camera follow updates on render frames with easing. Swings set
`CameraRig.follow_anchor` to a stationary marker, not the swinging seat. Cottage
entry saves the outdoor pose/view, hides/freezes outdoor actors and uses its own
camera; exit restores them. The room sits at world X=1000 on render layer 4, with
outdoor light masks avoiding leakage. The original 400×345 window SubViewport
is an in-scene texture inside the 1920×1080 frame, not a low-resolution test.

## Time and authority

Outdoor Worker authority is deliberately replaced with one local simulation.
Actor engagement, feeding/resources, seats/races and crop clocks do not sync with
browser players; contention/reconnect behavior is not claimed.

Crops and focus deadlines use Unix time for restart restoration. Swings/movement
use physics; race timing uses monotonic ticks and does not resume after restart.
Race gates are ordered, with swept proximity for fast crossings: 3-second
countdown, 90-second limit, 34-second rival lap.

Focus presets are 25/5, 50/10 and 10/2 minutes. The deadline continues outside the
cottage and triggers completion/chime locally. Base crop durations are carrot /
sunflower 300 seconds, radish 120, mint/daisy 180; `growth_duration()` adds farm rules.

## Local saved data

Godot resolves `user://` outside the source checkout. Obtain the actual directory
with `ProjectSettings.globalize_path("user://")` in the connected runtime. Do not
delete user data to fix an import/render issue.

| File | Contents and implementation |
| --- | --- |
| `preferences.cfg` | Language/weather/graphics/guide/reduced motion, sensitivity, soundtrack/mix, bindings; ConfigFile in `village_menus.gd` |
| `village-activities.json` | Version 1 beds, inventory/apples, cooking/dishes and forage; validated load and temporary write/flush/rename in `village_activities.gd` |
| `journal-notes.json` | Array of source-shaped `{id,text,createdAt}` entries; validated reads and write/flush/error-check/atomic rename in `village_journal.gd`; malformed reads block overwrites |
| `kind-note.cfg` | Kept English source phrase; daily UTC choice when no kept phrase, temporary ConfigFile/rename in `quiet_places.gd` |
| `focus-session.cfg` | Durations/intention, remaining/mode/deadline/completion; bounded load and temporary ConfigFile/rename in `focus_cottage.gd` |

Actor patrol/engagement, player position, occupied seats and races are not saved
by these files. Browser localStorage/Worker state are not imported. Journal
and kind notes are local; they do not modify browser storage. Future migrations must preserve existing user data;
use recoverable copies and restore state after test fixtures.

## Assets and provenance

World manifest source commit: `8594ca6c3a0477ca13b9e932c727104193b0f670`.
Layout SHA-256: `58c751fe6d008943434994d57c1b4fe71bbc791c4f6c3e25e7377056824bdf98`.
Source HEAD matches that commit at the audit. Helpers also read files directly;
this manifest is world provenance, not a full hash of native behavior/all assets.

| Folder | Purpose |
| --- | --- |
| `assets/village/` | Native batches/materials/textures, surface/map/navigation data and extraction manifest |
| `assets/spirit/`, `assets/animals/` | Original GLBs and import resources |
| `assets/gameplay/` | Source cooking/dish geometry |
| `assets/rest/` | Source room/desk/cat, moving swing parts, textures and seat metadata |
| `assets/shaders/` | Native environmental and clock shader adaptations |
| `assets/audio/` | Recordings and offline-baked cues/loops; no runtime web synthesis |
| `assets/fonts/`, `assets/ui/` | Outfit, Georgia SystemFont, icons and licenses |

Retain `assets/village/CREDITS.txt`, `THREE-LICENSE.txt`, Salamander license,
Outfit OFL and Phosphor license in packaging. Georgia uses a system font;
browser fallback/metrics need review. Godot Forge is a development plugin; its
runtime agent activates only with an attached debugger and adds no separate
standalone game network port.

## Quiet activity details

Journal keeps separate writing, scroll-preserving list and full-note views. Notes
are limited to 10,000 characters, retained on failed saves, and removed only after
confirmation. TXT backups use the original `Hearthwillow notes` header, ISO dates
and two-space-indented lines. Import parses everything before writing and merges
by occurrence counts of `(createdAt,text)` to preserve intentional duplicates
without multiplying them on repeated restores. Native file dialogs supply paths.

Pond routes use WorldSurface transforms for the enlarged pond and independent
dock. Natural creature sizes are retained. Feeding requires a crumb pouch
(`VillageLife.crumbs > 0`) without decrementing it, refuses another feed for 11
seconds, approaches during the first four seconds, celebrates at seven seconds
and departs from eleven to seventeen. Fish follow original 22-second jump cycles.
Breathing cycles are local elapsed time and reset on entry/exit; they are not
persisted. Experience reduced motion freezes native idle poses and fish jumps,
suppresses ritual/spirit motion and uses still ring cues while phase timers run.

QuietPlaces/PondLife disable physics interpolation for render-frame animation.
English typefaces retain Outfit/Georgia with explicit Japanese SystemFont
fallbacks, verified on this Mac; cross-platform font availability is unverified.

PondLife owns both dock feeding and the meal used by QuietPlaces/Breathe. Its
can_feed_here check gates distance, mounts, private/locked contexts and UI blocking;
nearby dock F wins over resident/animal F controls. No-pouch guidance is visible in
both views. The saved dock panel uses the shared interaction theme/button/keycap,
updates its content only when state changes and retains gameplay capture.


## 2026-10-13 activity and ambience parity

QuietPlaces owns music/tea/bird/garden camera and player locking. VillageActivities
owns garden state and Luma inventory transactions; garden UI visibility follows
QuietPlaces collapse/menu state, and both close paths clear ownership before
calling the other, preventing recursive leave. Map travel releases tower, quiet
place, seat, race, mount and cottage ownership before entering its destination.
Resident activity positions come from the original companion stages; entry saves
positions and leave restores them without losing following flags.

VillageLife owns resident formation/trail and fin contact, running after actor and
player physics (priority 10). Actors/player restore authored fin transforms every
physics tick before the temporary contact pose. Dogs retain their separate follow
slots. Static motes, tea cup, tower controls and camera are saved scene nodes.

Outdoor wind/rain/stream use the saved Outdoor low-pass bus. VillageSound blends
6500 Hz clear / 3500 Hz rain / 950 Hz cottage with existing shelter gain and moves
fire sound to the actual saved cottage flame. It excludes outdoor bird calls in
night/dusk/rain. VillageLighting caches materials with `motion_amount`; the saved
Reduce motion setting freezes decorative shader time without stopping growth,
focus, cooking or interaction clocks. Audio-off remains a global silence control.

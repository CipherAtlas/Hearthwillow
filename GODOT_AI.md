# Hearthwillow-port

Project memory for AI assistants (read by Godot Forge). Keep it short and current.

## Game
- Genre / pitch: Preserve the cosy-v1 village as a local Godot base game, Mac first.
- Core loop: Explore, talk to residents, spend time with animals, grow crops and cook.

## Conventions
- Scenes in res://scenes, scripts next to their scene, assets in res://assets.
- Typed GDScript, signals up / calls down.

## Art & audio
- Style: Original painted scenery, spirit, original recordings, Georgia/Outfit UI.

## Decisions
- Night lighting lives in saved village_lighting.tscn plus village_lighting.gd:
  ten spirit material baselines, painted window emission, 41 lantern halos,
  23 authored lamp nodes (only two active, selected at 10 Hz), and hearth light.
- Contact audio: walking gain .25, hoof gain .18, 220 ms minimum interval;
  source horse stride/scale cadence and distinct hoof recordings. Run
  milestone-night-audio and milestone-farm-horses after these changes.
- Source `/Users/sabar/Documents/cosy-v1` is read-only; no Worker, multiplayer, editor or admin.
- Saved scenes/resources are canonical; static content stays editable in the Godot editor.
- All visual tests/captures use true 1920×1080. Set view.game max_size=1920 explicitly.
- UI follows the live site: top-right menus/map, bottom-left movement instructions,
  bottom-right dog/animal/action controls and actual overhead NPC dialogue.
- Garden and farm clocks share original growth timings and the source clock treatment.
- Native seating/race/focus are saved sub-scenes; their initialization builder refuses
  to replace authored scenes. Swing cameras use stationary anchors, not moving seats.
- Focus deadlines use Unix time and an atomic local config; cat/room are private.
- Race invitations require talking to Rowan while unmounted; eight ordered gates.
- WorldSurface owns placement transforms and route-distance rules for collision/contact sound.
- User resumed sustained release FPS benchmarking on 2026-10-13. Use native
  1920×1080, representative moving scenarios and frame-time tails; no 120+ claim until measured.
- Read README.md for the documentation index, MILESTONE.md for status/backlog,
  docs/ARCHITECTURE.md for ownership/save contracts, docs/DEVELOPMENT.md for the
  safe workflow and docs/VERIFICATION.md for evidence boundaries.
- For downloadable builds and GitHub publication, follow DEPLOYMENT.md.
- Latest activity checkpoint: 2026-10-13, eight passing suites / 1,370 steps,
  lint 32 scripts / 12 scenes without errors/warnings; 12 native 1080p captures.
- Writing/journal/kind notes and pond life/breathing are implemented; journal
  saves/imports/exports preserve multiline notes and duplicate counts.
- Swings and picnic cushions choose facing from approach, T turns in place; W/S
  pump relative to facing. Keep picnic E eating/F basket available while locked.
- Reduced motion now reaches outdoor actors/shaders/rain, cameras, cottage and
  cooking/watering; clocks keep running. Japanese uses explicit system fallbacks.
- Live destination audit visited all 17 places; hearth/tea/birds/garden activity
  entry and tower lookout are restored. MILESTONE.md records scope and evidence.
- Completed release baseline: 16 views, 5s warmup +30s measured per view, native
  1080p Detailed/MSAA 4x. Night walk 70.3 FPS, hearth 72.0, lookout 59.5; 120 FPS
  fails. Measured snapshot predates final small corrections; see VERIFICATION.md.
- Live-parity regressions: four suites / 450 steps pass, 15 changed scripts clean;
  seven native captures are full 1920×1080. Physical listening/visual acceptance open.
- See evidence/quiet-validation-final.json and docs/VERIFICATION.md for boundaries.
- Map checkpoint: 17 fixed destination icons plus visitor only; never track NPCs,
  animals or dogs. Terrain is a cached TextureRect, visitor a separate CanvasItem;
  reflow captions only on view/selection/language changes. Delay resized layout
  until anchor offsets settle. Native map/capture suites pass 281 steps, lint 33/12.
- Mouse capture is the gameplay default. CameraRig owns explicit release state;
  VillageMenus restores capture when blocking UI closes. Starter, map/settings and
  private writing/cottage interfaces have a pointer. Seating/race do not force
  release; seat Escape records release before consuming the leave action.
- Dock feeding is a saved PondLife/UI panel and F input outside Breathe. Preserve
  the reusable pouch and one shared meal clock. Show Maple/Wren guidance with no
  crumbs; hide dock controls in map/menus/breathing and suppress competing actor F
  actions nearby. Duck/pond/resident checks pass 257 steps, including a real timed meal.
- Combined map/capture/duck Mac export rebuilt; startup exits 0 and nine packed GD
  hashes match source. Details/rollback are in docs/VERIFICATION.md and
  evidence/map-capture-ducks-validation.json. Exporter retains resources at exit;
  fresh package startup is clean. No sustained FPS claim.

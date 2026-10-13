# Development, conversion and handoff

[Documentation index](../README.md) · [Architecture](ARCHITECTURE.md) · [Verification](VERIFICATION.md)

## Ordinary run/edit workflow

Run commands from `/Users/sabar/Documents/ChatGPT/hearthwillow-port`. Godot 4.7.2
and the Mobile renderer are the tested configuration. The current executable is
`/opt/homebrew/bin/godot`; examples use `godot` when it is on PATH.

```sh
cd /Users/sabar/Documents/ChatGPT/hearthwillow-port
godot --editor --path .
```

Open `scenes/main.tscn`, inspect the relevant sub-scene and run the main game.
Edit static UI, transforms, lights and resources in their saved `.tscn`/`.tres`
files through the editor/Forge. Scripts should own behavior, not reconstruct an
already-authored interface every time the game starts.

Before editing, read applicable AGENTS instructions and the status/backlog,
inspect Git status and identify the source behavior to preserve. Original
`cosy-v1` stays read-only. Do not add dependencies, Git changes or deployment as
an implicit part of ordinary port work. Before the first public commit the checkout is untracked; inspect complete files
as well as Git diffs when reviewing that initial publication.

## Godot Forge workflow

The existing `addons/godot_forge` plugin connects the editor and running game.
Use project info and scene tree to orient; use node/scene/resource operations for
saved authoring and script operations for behavior. Script writes return compiler
diagnostics; resolve them before playing. Check unfamiliar APIs with Forge's
Godot docs/introspection instead of guessing engine syntax.

After external script edits, reload them through Forge script/file operations so
the editor does not retain a stale version. Rescan/reimport new assets before
assigning them to materials. Scene resources rewritten outside the editor also
need reopening; do not save a stale open scene over a newly saved version.

Use `test` with action `lint` for broken references and compile diagnostics. Run
an affected saved scenario by parsing its JSON and passing it as the `scenario`
argument to `test` with action `scenario`. The scenarios are under
`tests/scenarios/`; this project does not have a separate npm test runner.

For visual checks, restart the native game, confirm viewport 1920×1080 and call
Forge `view` with action `game` and `max_size: 1920`. Its default 1280 size is not
acceptable here. Full-size evidence can be saved from the runtime:

```gdscript
var picture: Image = scene.get_viewport().get_texture().get_image()
assert(picture.get_size() == Vector2i(1920, 1080))
picture.save_png("res://evidence/descriptive-name-1080p.png")
```

This snippet is for Forge's running-game execution context, where `scene` is
provided. A scene preview/static screenshot does not replace checking motion,
pointer interaction, text entry or actual audio output.

## Rebuilding the local Mac package

Export packages the current saved project; it does not reconstruct the village.
The preset is `Mac desktop`, universal architecture, free ad-hoc signing. Matching
Godot export templates must already be available.

```sh
godot --headless --path . --export-release "Mac desktop" \
  /Users/sabar/Documents/ChatGPT/hearthwillow-port/build/macos/Hearthwillow-port.app
```

A nonvisual startup smoke check is separate:

```sh
build/macos/Hearthwillow-port.app/Contents/MacOS/Hearthwillow-port \
  --headless --quit-after 30
```

Then launch normally and check the actual package at 1080p. A passing headless
startup cannot validate rendering, motion or sound. The current preset includes
runtime JSON/bin data and credits, excludes `scripts/`, `tests/` and `evidence/`
and selected development extraction files. Verify needed non-resource files are
included when adding an activity. Existing exports reported retained resources
at exporter shutdown; standalone startup/render logs are clean. Do not treat the
exporter's shutdown message as evidence of a game crash or ignore new app errors.

The 2026-10-13 quiet-activity rebuild passed export and startup smoke checks.
The preceding local bundle was retained at
`/tmp/hearthwillow-before-quiet-2026-10-13.zip` (temporary rollback, not user data).

Public Mac and Windows packaging is documented in [RELEASES.md](RELEASES.md).
The original local bundle remains a separate rollback; release artifacts are under
`build/releases/`. Publishing is a separate explicit action.

## Asset conversion versus authoring

Converted assets already exist. **Do not rerun all conversion/initialization scripts
as a normal build step.** They can replace saved art, controls and authoring.
For intentional regeneration, first make a recoverable copy of affected files,
confirm source commit/layout and regenerate only the required output. Review the
result in the editor before saving over existing scenes.

| Helper under `scripts/` | Purpose / boundary |
| --- | --- |
| `export_village.cjs` | Executes unchanged source builders to extract geometry/materials/instances, world/surface data and original assets; accepts source directory; uses existing Playwright/TypeScript/Three.js |
| `prepare_shaders.py` | Translates extracted environmental effects into native shaders |
| `prepare_audio.py` | Offline source-style ambience/contact synthesis and seamless MP3 loops; uses Python stdlib and existing ffmpeg |
| `prepare_gameplay.cjs` | Converts original recipe/dish/cooking geometry into `assets/gameplay/` |
| `prepare_map.cjs` | Converts original React map artwork/destinations into saved map assets |
| `prepare_garden_audio.py` | Bakes source garden/action sound cues |
| `prepare_quiet.cjs` | Extracts only original note/quill/page and bilingual kind phrases into `assets/quiet/`; does not reconstruct the world |
| `prepare_rest.cjs` | Converts room/desk/moving swing hierarchy and bench metadata, copies cat assets |
| `prepare_rest_audio.py` | Copies original cat/purr recordings and bakes the original two-note completion chime |
| `import_village.gd` | Initial saved-world conversion; can replace scene authoring; requires a real renderer |
| `import_animal_colors.gd` | Editor import processing for original vertex-colored animal models |
| `bake_navigation.gd` | Writes walkability grid from WorldSurface; regenerate after relevant geometry/surface changes |
| `build_activities.gd`, `build_leisure.gd`, `build_pond.gd`, `build_quiet_ui.py` | One-time initial scene construction; guards refuse existing authored activity/leisure scenes |
| `build_dialogue.gd`, `build_live_hud.gd`, `build_menus.py` | Historical initial UI construction; not a safe general refresh of current authored UI |
| `capture_entrance.gd` | Historical capture helper; confirm current 1080p requirement before reuse |

Some helpers have a hardcoded original source path, so inspect them before using
another checkout. Node/Three.js/React/TypeScript/Playwright are conversion tools,
not shipped runtime dependencies. Use existing installations; do not silently
install or upgrade packages for regeneration. This machine's bundled Node and
Playwright are under `~/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/`.
`PLAYWRIGHT_PATH` selects an existing Playwright module for the extracting helpers.
These machine-specific paths must be verified on another host.

Asset import may run headless:

```sh
godot --headless --editor --path . --import
```

The initial MultiMesh scene converter must not run headless: the dummy renderer
loses saved instance transforms. Using headless for imports or a nonvisual smoke
check is fine; using it to reconstruct this scene is not.

## Common failures and remedies

| Symptom | Check / remedy |
| --- | --- |
| Assets referenced before import | Rescan, wait for import/reimport, then assign/save |
| Scene loses controls or changes revert | Check scene ownership and stale editor cache; reopen after external saves |
| Empty/misplaced converted instancing | Check whether initial scene conversion used the dummy headless renderer |
| Original animal colors missing | Check native material vertex-color albedo and import processing |
| Pointer fixture misses a button on Mac | Focus the game window and move the real cursor before synthetic click |
| Held button stops during refresh | Preserve visible nodes; release on pointer-up/hide/exit and explicitly handle application focus loss |
| Temporary save mutation survives a test | Restore state before an autosave can serialize it; use the existing atomic fixtures |
| Screenshot appears low-resolution | Check viewport dimensions and Forge max_size; do not upscale it as acceptance evidence |
| Moviewriter cannot create files | Use absolute output paths; exported app working directory may differ |
| Early release frame is black | Allow initialization/drawing to complete before selecting a capture; check app logs and later frames |
| Historical errors appear in Forge | Distinguish old log entries from new errors in the current play session |

## End-of-change and next-session handoff

Run the smallest meaningful affected checks, resolve new diagnostics and review
all changed files for scope drift. Restart before final captures; record exact
1920×1080 evidence, input/fixture boundaries and runtime errors. Never substitute
an editor FPS point sample or movie capture for a sustained release benchmark.

Update MILESTONE status/backlog, relevant architecture/development details and the
verification evidence index. Keep GODOT_AI concise. Record what actually passed,
what was merely implemented and what needs user/device acceptance. Preserve
existing save data and the original source. Git writes/deployment require explicit
authorization; documentation does not grant it.

## Quiet activities and facing controls

Edit `quiet_places.tscn`, `pond_life.tscn`, `journal_note_row.tscn` and the seating
TurnAround button as saved authoring. QuietPlaces owns entry/exit/camera/poses;
VillageJournal owns paper views, native file dialogs and validated local storage;
PondLife owns source route/feeding/effect clocks. Reuse WorldSurface transforms
and the shared speech panel rather than drawing overlapping animal labels.

Run `milestone-quiet-notes`, `milestone-pond` and `milestone-seat-facing` scenarios.
The facing suite checks every swing slot and all five cushions from both sides,
including native T/pointer turning, W pumping after reversal and picnic basket
transitions. Journal fixtures use separate user://quiet-test-* paths and a saved
corrupt-data fixture under tests/fixtures; never substitute the real notes file.

Paper buttons use the saved quiet button theme with a 400-weight Outfit variation.
Georgia/Outfit have explicit Japanese SystemFont fallbacks; use glyph checks plus
1080p captures to verify Japanese, since string assertions cannot detect tofu.
System fonts are verified on this Mac only; browser/other OS delivery needs its
own font decision. Static authoring helpers refuse existing scenes.

The 2026-10-13 map/capture/dock-feed rebuild passes release startup and read-only
PCK script/asset verification. All nine changed packed GDScripts match the
verified source hashes. Prior bundle rollback is retained at
`/tmp/hearthwillow-before-map-capture-2026-10-13.zip`. See Verification for exact
logs, native screenshots and exporter-shutdown versus game-runtime boundaries.


## Native release FPS baseline

Benchmarking was resumed by the user on 2026-10-13. The opt-in harness is disabled
in ordinary play. Export to a separate local test app; do not replace public
release artifacts. Stop the editor game and close live-site audit tabs before
measurement. Keep the native render viewport at 1920×1080.

```sh
mkdir -p /absolute/path/to/local-test
godot --headless --path . --export-release "Mac desktop" "/absolute/path/to/local-test/Hearthwillow.app"
/absolute/path/to/local-test/Hearthwillow.app/Contents/MacOS/Hearthwillow-port -- --benchmark --benchmark-seconds=30 --benchmark-output=/absolute/path/to/fps.json
```

The harness specifies Detailed/MSAA 4x, shadows, VSync off, normal motion, enabled
sound and explicit weather per scenario, without saving these preferences.
Sixteen views each use 5 seconds warmup followed by 30 seconds measurement;
walking/horse cases issue real input and require more than 5 metres travelled.
Inspect runtime errors, release/renderer/resolution, movement verification and
frame-time tails before interpreting averages. Hash the measured runtime files
and retain export/run logs. Keep normal desktop/background-load and thermal
limits explicit; this baseline alone does not establish sustained 120+ FPS.

# Verification, evidence and acceptance

[Documentation index](../README.md) · [Status/backlog](../MILESTONE.md)

Updated **2026-10-13** with native gameplay and 1920×1080 visual checks. FPS
benchmarking was resumed by the user on 2026-10-13; new results follow below. Steps include fixtures, input, waits and assertions,
not independent assertions. Prior 2026-10-12 evidence remains retained below.

## 2026-10-13 night lighting and quiet movement audio

Compared the actual live night scene in the browser and read the source
world.ts, villageVisitors.ts, VillageEngine.ts, water.ts, horseAudio.ts and
horseModel.ts. Daytime extraction had omitted inactive lights and lantern halos;
native runtime also lacked the original glass/spirit weather updates. Restored
saved fixtures and runtime behavior without rerunning the scenery converter.

- `milestone-night-audio`: 67 steps pass, no runtime errors. Native viewport,
  night/dusk/rain/day transitions, all ten spirit baselines restored, painted
  window emission, halo visibility, two-lamp budget and town lamp selection;
  quiet surface/hoof clips, callback limit, idle silence and sound-off stop.
  Direct audio assertions freeze player physics temporarily to keep the stimulus
  stable between remote calls; the horse suite separately checks real movement.
- `milestone-farm-horses`: 125 steps pass, no runtime errors, including native
  mount/riding/trot/canter/braking/dismount and existing animal/forage controls.
- Changed-script language-server diagnostics: all four clean. Whole-project lint
  reports eight errors exclusively in `build/templates/forge-upstream.gd`, a
  downloaded reference file from concurrent release preparation; game scripts
  and saved scenes compile. This is not a clean whole-project lint claim.
- Menu suite: initial guide assertion depends on saved skip-guide preference;
  with a runtime guide fixture it then stops at a Settings pointer/focus assertion.
  No runtime error; no passing menu-regression claim. Preferences used by this
  attempt were copied/restored afterward.

Evidence: [scenario results](../evidence/night-audio-validation.json),
[fixture provenance](../evidence/night-fixture-provenance.json),
[native night entrance](../evidence/night-fixed-spawn-1080p.png) and
[native village night overview](../evidence/night-fixed-village-1080p.png).
Both images are exactly 1920×1080 from the restarted native Mobile renderer.
The prior night image is retained separately; its camera differs, so it is not a
pixel-difference baseline. Numeric audio checks do not establish physical listening
acceptance. At that earlier checkpoint, the broader place-controls/weather audit
and sustained FPS benchmark were still pending; the completed audit/run follows
below. Public release packages are managed
by the separate release chat; this checkpoint does not update or publish them.

Local test app: `build/night-audio/Hearthwillow.app`. Export exits 0 with the
previously observed exporter shutdown resource warning; deep/strict ad-hoc
signature verification and standalone headless startup pass. All six changed
packed code/scene/shader hashes match the current source; the pack contains all
41 halos, 23 lamp nodes and the hoof cues. A render of the exported pack in the
matching installed engine is [1920×1080](../evidence/night-audio-package-1080p.png)
and asserts two active lamps. The actual app's starter was visually checked
through native UI; its release template ignores the external --script capture
helper, so the 1080p pack capture is not an app-executable capture. Logs are
`night-audio-mac-export.log`, `night-audio-mac-startup.log`,
`night-audio-packed-render-host.log` and `night-audio-pack-audit-host.log` under
evidence. Signature/startup checks use the actual app executable. This app lives apart
from the concurrently prepared public downloads; no release files are replaced.

## 2026-10-13 duck feeding at the dock

The original site's Garden targets include a nearby dock feed action. The port's
meal animation existed, but F and its button were only wired inside Breathe, and
no-pouch visitors saw no feed button. PondLife now owns a saved, compact dock panel
and F input outside activities. It shares the same reusable pouch, crumbs, swim
approach, 11-second cooldown, hearts/thanks and 17-second departure with breathing.
Both views show Maple/Wren guidance without hiding the mechanic. Dock feeding
reserves its contextual F control and suppresses conflicting nearby actor actions;
menus/map hide the panel. Feeding does not release gameplay mouse capture.

| Saved scenario | Steps | Fresh evidence / coverage |
| --- | ---: | --- |
| `milestone-duck-feeding` | 67 | [Dock feeding](../evidence/duck-feeding-final.json): no-pouch panel, real Maple proximity/B crumb request, dock F, retained pouch, cooldown/repeat refusal, actual timed approach/hearts/thanks/departure, pointer feeding, map/settings hiding, seated breathing, Japanese and walking away |
| `milestone-pond` | 99 | [Pond regression](../evidence/duck-pond-regression.json): existing swimming/fish/feeding/breathing, clock boundary fixtures, reduced motion and activity transitions |
| `milestone-npcs` | 91 | [Resident regression](../evidence/duck-npc-regression.json): existing resident/dog/owl/bird/crumb controls remain valid |

All three pass with no runtime errors. The dock suite uses elapsed real time for
its complete meal; it does not set feed_at or grant a crumb pouch as a fixture.
The existing pond regression still uses explicit timing fixtures. Final
[lint](../evidence/duck-feeding-lint.json) is clean: 33 scripts / 12 scenes.

Native captures are 1920×1080:
[no pouch](../evidence/duck-feeding-no-crumbs-1080p.png),
[hearts and thanks](../evidence/duck-feeding-happy-1080p.png),
[Japanese](../evidence/duck-feeding-japanese-1080p.png).

## 2026-10-13 map and mouse capture checkpoint

The map now displays only the visitor and 17 fixed destinations. NPC, animal and
dog positions/names are absent from both map modes. The original landscape remains;
markers use separate white textures tinted for contrast, persistent selection,
15px captions, fit/zoom controls, north/scale guides and collision-aware labels.
Japanese title/footer use the existing Georgia font with explicit fallbacks.

| Saved scenario | Steps | Fresh evidence / coverage |
| --- | ---: | --- |
| `milestone-map` | 199 | [Map](../evidence/map-scenario-final.json): 1080p viewport, mini pointer opening, all 17 icons, keyboard selection, pointer pan and zoom/reset, real wheel input, zoom limits, offscreen selection recovery, Japanese text/title glyph, native footer travel to every destination, close/reopen and safe arrivals |
| `milestone-mouse-capture` | 82 | [Mouse capture](../evidence/mouse-capture-final.json): starter pointer, immediate gameplay capture/camera motion, explicit Escape release, preservation across HUD sync, click recapture, map/settings/sound/inventory toggle and Escape closure, seat entry/exit and mounted race start |

Both scenarios pass with no runtime errors. [Lint](../evidence/map-lint-final.json)
checks 33 scripts / 12 scenes with zero errors/warnings. Test snippets observe
Godot's actual Input.mouse_mode; they do not infer capture from a HUD label.
Language fixtures change only runtime properties and restore the starting language.

[Redraw measurement](../evidence/map-redraw-final.json) counts CanvasItem.draw signals:
mini and expanded maps each had **zero map and visitor redraw callbacks** in roughly
two-second idle samples. There were 25 actors; 16 moved during the mini sample and
17 during the expanded sample. The previous map scheduled drawing every 80ms and
scanned actors inside its draw callback. The new landscape is a cached TextureRect;
labels only reflow on view/selection/language changes and the visitor has a separate
CanvasItem. Godot still renders cached drawing commands each frame. This measures
removed update work, **not a sustained FPS, GPU or whole-game performance benchmark**.

Fresh native captures, all 1920×1080:
[expanded](../evidence/map-rework-1080p.png),
[minimap](../evidence/map-rework-mini-1080p.png),
[Japanese](../evidence/map-rework-japanese-1080p.png).
Visual acceptance and the deferred sustained 120+ FPS target remain open.
The later combined map/capture/duck export is recorded below.

## Combined local Mac build

[Validation record](../evidence/map-capture-ducks-validation.json) retains source,
packed-script, executable/PCK and screenshot SHA-256 values for this change.
The local `build/macos/Hearthwillow-port.app` was rebuilt with the existing Mac
preset. Release-executable startup (`--headless --quit-after 30`) exits 0 with no
errors: [startup log](../evidence/map-duck-package-startup.log). Read-only PCK
inspection using the installed Godot runtime confirms 17 destinations, 12 map
textures, map/capture/dock-feed code and exact matching hashes for all nine changed
GDScripts: [package resource log](../evidence/map-duck-package-resources.log).

[Export log](../evidence/map-duck-export.log) records exit 0 and the previously
observed exporter-shutdown resource retention messages (66 ObjectDB instances,
31 resources). Fresh packaged startup is clean. Native gameplay/1080p evidence
comes from the editor game; headless startup and PCK inspection do not independently
establish packaged visual/audio or physical-device acceptance. Sustained FPS remains
deferred. Rollback bundle: `/tmp/hearthwillow-before-map-capture-2026-10-13.zip`.

## 2026-10-13 quiet activities and facing checkpoint

[quiet-validation-final.json](../evidence/quiet-validation-final.json) records
**eight passing suites / 1,370 steps**, lint of **32 scripts / 12 scenes** with no
errors/warnings, and SHA-256/dimensions for twelve 1920×1080 captures.

| Saved scenario | Steps | Fresh evidence / coverage |
| --- | ---: | --- |
| `milestone-quiet-notes` | 142 | [Notes](../evidence/quiet-notes-final.json): native text/shortcuts, Japanese glyphs, save/load, write/list/read, delete/keep, scroll restoration, 10,000-character note, TXT duplicates/idempotence/invalid dates, damaged read/write failures, file-dialog wiring, kind E/K/pointer/keeping/language/exit |
| `milestone-pond` | 99 | [Pond](../evidence/pond-final.json): actual route motion, flock/fish counts, pouch/cooldown, arrival/hearts/single reply/departure, phase boundaries/pause/reset/pattern keys and clicks, reduced motion, cottage/map/nearby entry and dry exit |
| `milestone-seat-facing` | 385 | [Facing](../evidence/seat-facing-final.json): both approach sides on all four swings and five cushions, T/pointer turning, unchanged seat/anchor, W pumping after each reversal, basket and exits |
| `milestone-menus` | 92 | [Menus](../evidence/quiet-menus-final.json): affected menu/map/input regressions |
| `milestone-focus` | 86 | [Focus](../evidence/quiet-focus-final.json): cottage/timer/save/input/return regressions |
| `milestone-seating` | 201 | [Seating](../evidence/quiet-milestone-seating-final.json): benches/cushions/swings/native pointer/basket regressions; cushion heading assertions reflect the new facing choice |
| `milestone-garden-kitchen` | 274 | [Garden/kitchen](../evidence/quiet-milestone-garden-kitchen-final.json): crops/recipes/eating/save regressions; seated picnic access preserved |
| `milestone-npcs` | 91 | [Residents](../evidence/quiet-npcs-final.json): resident/animal/speech/feeding regressions |

Tests read/write isolated journal/kind-note fixture files; existing personal saves
are not overwritten. File dialogs are opened and wiring checked; path-based TXT
round-trips use fixture files. This does not prove every native OS chooser flow.
Pond phase/meal boundaries use clock fixtures alongside actual timed movement and
input; this is not an unaided 17-second feeding playthrough. Live-site source
behavior/art/camera/CSS is the reference, not a pixel-equivalence claim.

| New native image | Review |
| --- | --- |
| [Writing](../evidence/journal-writing-1080p.png), [list](../evidence/journal-list-1080p.png), [reading](../evidence/journal-read-1080p.png), [Japanese](../evidence/journal-japanese-1080p.png) | Paper views, readable controls, multiline content and corrected Japanese glyphs; displayed notes are staged fixtures |
| [Kind note](../evidence/kind-note-1080p.png), [Japanese](../evidence/kind-note-japanese-1080p.png) | Original phrases, envelope/sheet/reader pose and E/K controls |
| [Breathing](../evidence/pond-breathing-1080p.png), [feeding](../evidence/pond-feeding-1080p.png) | Open-bank view, native families/fish/rings, cooldown controls, hearts and one cream nearest-animal reply; feed clock is staged |
| [Swing forward](../evidence/swing-forward-1080p.png), [reverse](../evidence/swing-reverse-1080p.png) | Same real seat, opposite view/facing and Turn around button |
| [Cushion forward](../evidence/picnic-forward-1080p.png), [reverse](../evidence/picnic-reverse-1080p.png) | Same cushion, opposite facing/view and independent basket/stand/turn controls |

Captures follow native restarts, use Forge max_size=1920 and verify PNG dimensions
at 1920×1080. They do not establish physical audio, full-motion subjective quality,
all-weather behavior, browser support or sustained FPS.

### Local Mac export for this checkpoint

[quiet-mac-export.log](../evidence/quiet-mac-export.log) records successful release
export (exit 0), including the new kind-notes JSON and native scenes/fonts/assets.
The exporter again reports retained ObjectDB/resources at its own shutdown.
[quiet-release-startup.log](../evidence/quiet-release-startup.log) and the
[180-frame verbose smoke](../evidence/quiet-release-startup-full.log) exit 0 with
no runtime errors. [Native Metal starter](../evidence/quiet-release-starter-1080p.png)
is also verified at 1920×1080; [render log](../evidence/quiet-release-render.log)
is clean. Fixed-timestep movie mode supplied that image and is not an FPS test.
The previous local bundle is recoverable from
`/tmp/hearthwillow-before-quiet-2026-10-13.zip`. This is an unsigned local build;
a full standalone activity playthrough and physical sound acceptance remain open.

## Previous 2026-10-12 consolidated checkpoint

[leisure-validation-final.json](../evidence/leisure-validation-final.json) records
13 passing scenarios / 1,196 steps and lint of 27 scripts / eight scenes with zero
errors/warnings. The ten prior suites are summarized in
[leisure-regressions-final.json](../evidence/leisure-regressions-final.json).
Saved reproducible scenario definitions are in `tests/scenarios/`.

| Scenario filename | Latest recorded steps | Coverage |
| --- | ---: | --- |
| `milestone-animal-controls.json` | 44 | Dog pointer/keyboard/tricks/close, rebound keycap padding, walking/home |
| `milestone-farm-horses.json` | 125 | Forage, pasture feeding, native horse movement/feed/dismount |
| `milestone-garden-kitchen.json` | 274 | Crops/farm rules, four recipes, picnic basket/cushion flow, portions, atomic save fixture |
| `milestone-gifts.json` | 46 | Original Luma gift keys/replies, tea and basket |
| `milestone-growth-clocks.json` | 66 | World countdown treatment, garden-card clocks and growth state |
| `milestone-menus.json` | 92 | Starter/guide, settings/sound, rebinding, map travel and pointer controls |
| `milestone-npcs.json` | 91 | Residents, animal interactions and seated bird feeding |
| `milestone-collisions-camera.json` | 38 | Obstacles, water boundaries and camera behavior |
| `milestone-bridges.json` | 36 | Four bridge crossing checks |
| `milestone-exploration.json` | 24 | Initial movement/exploration integration |
| `milestone-seating.json` | 201 | All seats, native seat click, picnic shortcuts, swing direction/brake/limits/stationary anchor |
| `milestone-race.json` | 73 | Invitation/countdown, native movement, ordered gates/results, cancellation/dismount |
| `milestone-focus.json` | 86 | Timer/presets/pointer/keyboard/save/break/chime, text-input protection, cat/purr/map/return |
| **Total** | **1,196** | **836 prior regression steps + 360 leisure steps** |

Detailed leisure reports: [seating-final.json](../evidence/seating-final.json),
[race-final.json](../evidence/race-final.json),
[focus-final.json](../evidence/focus-final.json). These match current scenario counts.

### Older reports are retained, not silently rewritten

The latest garden/NPC reruns are recorded in the consolidated summary. Older
raw `milestone-garden-kitchen-final.json` and `milestone-npcs-final.json` contain
266 and 88 steps respectively, rather than current 274 and 91. Similarly,
`bridge-results.json` has 33 steps and `collision-camera-results.json` has 32;
current definitions/latest summary have 36 and 38. These files document earlier
fixtures and are not complete raw transcripts of the latest reruns. Do not claim
that every old `*-final.json` is the latest evidence simply because of its name.

## Native input versus fixture coverage

Scenarios directly prepare some positions, timer deadlines and race gates to test
state boundaries quickly. Such fixtures establish behavior under those states;
they do not prove an entire unaided playthrough or natural elapsed timing.

A separate [continuous race trace](../evidence/race-continuous-1080p.json) records
native held W/Shift and A/D steering through all eight gates to a visitor win,
without overriding position, speed, gate or race clock. This supplements the
fixture-driven gate/result checks. Pointer checks include native bench selection
and held horse-forward across refreshes. Save fixtures restore original local
activity/focus state after testing.

Focus completion outside the cottage, restored deadlines, sound controls,
automatic indoor soundtrack, suppressed indoor birds, purr and completion chime
have functional evidence. This does not establish physical sound quality.

## 1080p visual evidence

Captures are native viewport PNGs, not upscaled previews. The Mac desktop window
frame can clamp visible window size to 1918×1079 while the render target remains
1920×1080; acceptance is based on verified native render dimensions. Forge's
capture max_size must be set to 1920.

| Capture | What was reviewed |
| --- | --- |
| [dog-controls-live-style-1080p.png](../evidence/dog-controls-live-style-1080p.png) | Dog panel placement, icon, bordered actions/keycaps and trick layout |
| [animal-keycaps-live-style-1080p.png](../evidence/animal-keycaps-live-style-1080p.png) | Animal action typography/keycaps/placement |
| [horse-keycaps-live-style-1080p.png](../evidence/horse-keycaps-live-style-1080p.png) | Horse direction/held/action card |
| [kitchen-keycaps-live-style-1080p.png](../evidence/kitchen-keycaps-live-style-1080p.png) | Recipe and kitchen action treatment |
| [garden-growth-clock-1080p.png](../evidence/garden-growth-clock-1080p.png) | Crop/world clock treatment and placement |
| [village-map-1080p.png](../evidence/village-map-1080p.png) | Map artwork, markers/labels and interface |
| [bench-seating-1080p.png](../evidence/bench-seating-1080p.png) | Bench slot/pose, original facing and stand-up card |
| [meadow-swings-1080p.png](../evidence/meadow-swings-1080p.png) | Native moving seats, frame alignment, stationary view and controls |
| [rowan-race-1080p.png](../evidence/rowan-race-1080p.png) | Top-center progress HUD, gate/riding view, integrated F Leave race |
| [focus-cottage-1080p.png](../evidence/focus-cottage-1080p.png) | Room/window/fire/desk composition and session controls |
| [cottage-cat-1080p.png](../evidence/cottage-cat-1080p.png) | Original desk cat and cream speech bubble; cat state staged for capture |
| [leisure-release-starter-1080p.png](../evidence/leisure-release-starter-1080p.png) | Standalone Mac app's Metal-rendered starter |

Leisure captures were taken after native game restarts. The room's original
400×345 bridge-window texture is internal scene content inside the 1080p render.
The live reference used source DOM/computed CSS; the in-app browser capped its
viewport at 1600×900, so no low-resolution browser screenshot was used as visual
acceptance. Static images do not prove wind/gait/camera motion or exact site parity.

## Mac export evidence

- [leisure-mac-export.log](../evidence/leisure-mac-export.log): release export exit 0;
  exporter reports retained resources/ObjectDB instances during its own shutdown.
- [leisure-release-startup.log](../evidence/leisure-release-startup.log): bundled
  executable passes a headless 30-frame startup smoke with no runtime errors.
- [leisure-release-render.log](../evidence/leisure-release-render.log): native
  Metal rendering and starter capture; no app runtime errors recorded.

Movie mode supplied frames for the standalone capture. Its fixed timestep is
**not a performance measurement**. Starter rendering/startup is checked; a full
standalone playthrough of every new activity is still outstanding. The bundle
is unsigned/unnotarized and has no public distribution acceptance.

## Historical performance evidence — not final acceptance

The user resumed sustained release benchmarking on 2026-10-13. The historical
eight-second samples per view (three-second warmup) below are
short prior diagnostics, do not represent the latest release comprehensively,
and were not collected under an accepted clean sustained-test condition.

| Historical report | Average FPS range across its views | Meaning |
| --- | --- | --- |
| [release-baseline-1080p.json](../evidence/release-baseline-1080p.json) | 54.9–66.4 | Earlier baseline, already below 120 |
| [release-npcs-1080p.json](../evidence/release-npcs-1080p.json) | 33.2–48.4 | Earlier actor-populated scenes, also below target |

The current `release_benchmark.gd` is disabled in ordinary play. It accepts
`--benchmark`, `--benchmark-seconds=` and `--benchmark-output=` as user arguments
(after Godot's `--` separator). It uses five fixed views and brief warmup; extending
that harness/scenario selection is required before final acceptance, including
new gardens/racing/swings/cottage and representative moving camera paths.

When the user resumes performance work: use the matching saved-source release,
1920×1080 full pixel budget, record graphics/weather/save population, runtime/OS/
hardware and background load; warm caches; measure sustained frame times across
all representative activities. Report average and low-tail behavior plus p95/p99
frame times and thermal-duration limitations. Do not use an editor point sample,
headless run, movie mode or reduced render resolution to claim 120+ FPS.

## Final acceptance still required

1. Finish missing base-game activity systems and their source-shaped controls.
2. Repeat affected regressions and native 1080p visual/motion checks after changes.
3. Review complete live-site parity, map quality, dialogue, all-weather lighting,
   wind and camera transitions with the user.
4. Perform physical listening checks and broader standalone Mac activity tests.
5. After the user's resumption, optimize and benchmark the final release honestly
   against sustained 120+ FPS, preserving the required look and pixel budget.
6. Complete the later browser renderer/export/audio/input/persistence milestone
   and actual browser checks. No web/native mobile acceptance exists yet.


## 2026-10-13 live destination parity and sustained release measurement

[Live evidence](../evidence/live-destination-audit.json) records all 17 destination
visits. The audit distinguishes automatic activities from ground arrivals with
nearby controls. Source comparison covers activity/companion stages, low-pass and
rain mixing, weather time boundaries, reusable feeding pouch and reduced motion.
It does not establish exhaustive visual equivalence or multiplayer parity.

[Native regressions](../evidence/parity-regressions.json) pass four suites:
165-step live parity, 67-step night/audio, 125-step farm/horse and 93-step NPC
(450 steps total, no runtime errors). The NPC fixture explicitly sets English
and checks the source reusable crumb pouch. [Gameplay diagnostics](../evidence/parity-gameplay-diagnostics.json)
are clean for all 15 changed scripts. Whole-project Forge lint still reports ten
errors exclusively in ignored build snapshots/reference scripts.

The measured export completes with exit 0; known headless exporter shutdown
resource warnings are retained in [export log](../evidence/parity-current-export.log).
The native benchmark exits 0 without runtime errors.

The [initial baseline](../evidence/parity-baseline-fps.json) measures five outdoor
views for 30 seconds each. It averages 84.1–142.0 FPS, p99 10.4–16.5 ms and fails
sustained 120 FPS. Its saved preferences were not fully recorded, so comparisons
with the following deterministic Detailed/weather run are descriptive only.

The new opt-in `release_benchmark.gd` waits for world readiness, specifies graphics,
weather, sound and normal motion without saving preferences, warms each scene for
5 seconds and measures 30 seconds. It covers 16 views including actual walking
and horse input, rain/clear/night, hearth/tea/garden/birds/lookout/cottage. Reports
contain averaged frame/engine-process/physics/draw-call values, p95/p99/worst frame times and
actual travelled metres. Exported app: `build/parity-current/Hearthwillow.app`.
The editor game and live audit tab are closed during measurement; the editor and
normal desktop remain open. No movie capture or lowered-resolution viewport is
used. This is a sustained scenario baseline, not a long-session thermal or 120 FPS
acceptance test. The run completed; results follow.


[Full release report](../evidence/parity-current-fps.json), Apple M4 / Mobile,
Detailed graphics, MSAA 4x, sun shadows, sound on, normal motion, VSync off:

| Scenario | Average FPS | p95 ms | p99 ms | Worst ms |
| --- | ---: | ---: | ---: | ---: |
| entrance day | 129.6 | 10.04 | 13.01 | 17.78 |
| village night | 125.9 | 13.43 | 17.41 | 72.80 |
| western bridge day | 106.2 | 13.55 | 16.70 | 26.37 |
| pond day | 88.7 | 15.48 | 17.39 | 23.10 |
| pond rain | 84.8 | 16.24 | 17.98 | 21.47 |
| hill picnic day | 90.1 | 17.50 | 19.33 | 45.50 |
| walking village day | 85.7 | 15.66 | 18.13 | 21.77 |
| walking village night | 70.3 | 17.94 | 21.41 | 55.92 |
| horse canter day | 118.2 | 13.36 | 16.71 | 45.83 |
| horse canter night | 104.8 | 14.47 | 16.34 | 21.82 |
| hearth night | 72.0 | 17.49 | 19.50 | 23.57 |
| tea day | 76.1 | 16.39 | 17.78 | 20.18 |
| garden day | 82.7 | 15.21 | 16.79 | 19.65 |
| birds day | 94.0 | 14.19 | 15.89 | 19.61 |
| lookout night | 59.5 | 19.96 | 22.35 | 25.98 |
| cottage rain | 173.6 | 12.40 | 16.66 | 1007.40 |

All four movement cases travelled more than five metres (walking 88.3 m, horse
59.5–59.6 m). Input alternates forward/backward every five seconds; horse forward
segments hold canter and reverse segments remain part of the measured case.
Travel totals include warmup. Every p99 exceeds the 8.33 ms budget for 120 FPS;
these results do not meet sustained 120 FPS. The cottage's 1007.4 ms outlier needs
separate investigation. `TIME_PROCESS` is an inclusive engine monitor, including
rendering/waits; it does not isolate script CPU work or prove a CPU/GPU bottleneck.

[Source hashes](../evidence/parity-current-source-hashes.json) identify the measured
snapshot. The final tea-button contrast, flock reduced-motion pose and companion
stopping/avoidance corrections were made afterward. Their current-source checks
pass, but these FPS numbers do not describe a bit-identical final build. The
measured app remains at `build/parity-current/Hearthwillow.app`; the final local
export is `build/parity-final/Hearthwillow.app`. Neither replaces public releases.

Full native viewport captures are all verified 1920×1080:
[hearth](../evidence/parity-hearth-1080p.png),
[tea English](../evidence/parity-tea-1080p.png),
[tea Japanese](../evidence/parity-tea-japanese-1080p.png),
[garden](../evidence/parity-garden-1080p.png),
[birds](../evidence/parity-birds-1080p.png),
[lookout](../evidence/parity-lookout-1080p.png), and
[companion formation](../evidence/parity-companion-1080p.png).
These establish the captured native layouts, not exhaustive live visual parity
or physical-device listening acceptance. Pre-test user saves are restored after
verification, with post-test state retained separately in the temporary backup.


Final local export [log](../evidence/parity-final-export.log) exits 0 with the same
headless exporter shutdown resource warnings. Its actual executable's headless
startup [log](../evidence/parity-final-startup.log) exits 0 without errors/warnings;
this confirms startup, not release visual acceptance. [Final source hashes](../evidence/parity-final-source-hashes.json)
record the current gameplay snapshot. [Save restoration](../evidence/parity-save-restoration.json)
records hash-verified restoration of every pre-test file and the separate post-test
backup. No public package, Git history or source village files were changed.

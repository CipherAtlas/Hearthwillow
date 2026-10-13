# Port status and remaining work

Audited **2026-10-13** against current files and recorded evidence. Latest
activity implementation/tests: **2026-10-13**. The requested 16-scenario release
benchmark is complete; sustained 120 FPS is not met.

Latest live-parity checkpoint: all 17 live destinations audited, four affected
native suites / 450 steps pass, 15 gameplay scripts clean, seven full 1080p
captures. Hearth/tea/birds/garden, lookout, companion staging, weather audio and
reduced motion changes are verified. Full results and remaining acceptance work
are recorded in the final section below.

Night/audio checkpoint: source-shaped window and lantern emission, 41 saved
lantern halos, ten glowing spirit materials, two nearest outdoor lamp lights,
hearth illumination and water/bounce weather treatment are restored. Walking
contacts use 25% gain; riding uses distinct original hoof synthesis at 18% gain,
source stride/scale cadence and a 220 ms audio limit. Night/day/dusk/rain and
horse suites pass 192 steps; four changed scripts have clean diagnostics and two
new captures are native 1920×1080. Full-project lint is blocked by a downloaded
reference script under build/templates; the menu pointer fixture also failed.
See Verification. Broader base-game parity and physical listening remain open.

Latest map/capture checkpoint: two passing native scenarios / 281 steps, lint
33 scripts / 12 scenes clean, three 1080p captures. Both map modes recorded zero
idle draw callbacks while actors continued moving. This is map update evidence;
this earlier checkpoint did not measure sustained FPS. See docs/VERIFICATION.md.

Dock feeding now has its own nearby F/button path with no-pouch guidance, shared
cooldown and retained pouch. Three affected suites pass / 257 steps, including
actual elapsed-time feeding and existing pond/resident regressions. Native
captures are 1080p; final lint remains clean. The combined Mac app is rebuilt,
startup passes and packed script hashes match the verified source. See
docs/VERIFICATION.md for evidence and rollback.

## Download distribution — 2026-10-13

Public GitHub repository and Mac/Windows preview downloads are authorized. Mac
uses free ad-hoc signing without notarization; Windows targets x86_64 unsigned.
Packaging does not add multiplayer. The user has now separately resumed FPS benchmarking. See
[release preparation](docs/RELEASES.md) for artifacts and verification boundaries.

## Required outcome

Port the existing `cosy-v1` base game into Godot, Mac desktop first and browser
later. Run locally, preserve original art/dialogue/live-site controls, improve
inconsistent placement, and standardize shared rules. No custom editor, admin,
Worker or multiplayer. The ordinary Godot editor remains the authoring tool.

Active quality requirements: fluid camera, working NPCs and activities, polished
lighting/wind/sound, a better map and sustained 120+ FPS at 1080p. All visual tests
must use **1920×1080**. The user resumed the release FPS benchmark on 2026-10-13.

## Implemented systems

“Implemented / checked” means native behavior with retained local evidence. It
is distinct from exhaustive source parity and final user acceptance.

| System | Delivered behavior | Main files | Remaining boundary |
| --- | --- | --- | --- |
| World | 1,139 batches, 501 geometries, 166,982 instances, 188 materials, 28 textures saved natively | `village.tscn`, `assets/village/` | Initial conversion must not overwrite later authoring |
| Movement/collision | Spirit walk/dash/jump/glide, recovery, terrain/obstacles, water boundaries, four bridges | `player.gd`, `world_surface.gd` | Full-map edge review remains after future changes |
| Camera | Render-frame follow, eased orbit/zoom, obstruction recovery, stationary swing anchor, cottage camera; automatic gameplay capture / Escape release / UI-close recapture | `camera.gd`, `village_seating.gd`, `focus_cottage.gd` | Subjective motion acceptance remains open |
| Environment | Painted assets, native sky/water/flame/wind, weather and lighting transitions | `assets/shaders/`, `village_menus.gd` | All-weather lighting/wind parity still needs review |
| Residents | Nine residents, local routes, conversations and nearby actions | `village_actor.gd`, `village_life.gd`, `village_dialogue.gd` | Single local simulation replaces Worker authority |
| Animals | Four dogs, three owls, six pasture animals, hedgehog, two horses; feeding/tricks/following/riding | `village_actor.gd`, `village_life.gd`, `player.gd` | Native pond families/fish/feeding now delivered; local authority only |
| Doves | Original parts/path, flight, landing, crumbs and meal phases | `village_flock.gd` | Clearing anchor still uses a fixed convention |
| Map/routes | Original SVG, 17 fixed destination icons, framed fit/zoom/pan, cached drawing; visitor only, no actor tracking; 53 paths, three rivers | `village_map.gd`, `map_visitor.gd`, `world_surface.gd` | “Better than browser” has no completed user acceptance |
| Menus | Starter/guide, Experience/Sound/Controls settings, rebinding/conflicts, language, inventory | `menus.tscn`, `village_menus.gd` | Language popup and full localization/accessibility parity need review |
| Action UI/dialogue | Top-right menus/map, bottom-left movement hints, bottom-right action cards, cream overhead dialogue | `village_dialogue.gd`, `interaction_button.gd`, shared themes | Source look is the target; pixel equivalence is not established |
| Audio | Original recordings, spatial ambience, crossfades/contact/action cues, six mix channels and soundtrack choice | `village_sound.gd`, `assets/audio/` | Physical listening and exact indoor filtering acceptance remain open |
| Crops/garden | Seven beds, fifteen farm rows, plant/water/grow/harvest, original world/overview clocks, local saves | `village_activities.gd`, `growth_clock*.gd` | No browser/shared save migration |
| Gifts | Luma gifts, source replies, staged tea seating, mint/sip/cup/steam and basket travel | `village_activities.gd`, `quiet_places.gd` | Local inventory replaces shared harvest authority |
| Kitchen/picnic | Four recipes, ingredients, timers, packing, dishes/portions and bite cooldown | `activities.tscn`, `village_activities.gd` | New flow is F basket / E seated eating; older fixtures differ |
| Seats | Seven locations / 17 slots, five picnic cushions, facing/height, pointer seat choice, bird feeding, safe exits | `seating.tscn`, `village_seating.gd` | Local occupancy only |
| Swings | Two pairs, pendulum motion, level seats, W/S pump, both facing directions, approach-side selection, T turn, Space brake and stable camera | `seating.tscn`, `village_seating.gd` | Final motion/sound acceptance remains open |
| Race | Rowan invitation, available horse, 3-second countdown, eight ordered gates, rival/rider, HUD/results/cancel | `race.tscn`, `village_race.gd` | Successful native play does not establish every source detail |
| Cottage | Original room/desk/cat, bridge window, steam/hourglass/quill, presets/intention, saved timer, break/pet/bubbles/purr/chime | `focus_cottage.tscn`, `focus_cottage.gd`, `cottage_cat.gd` | Final animation/audio/lighting acceptance remains open |
| Journal | Writing nook, 10,000-character notes, separate write/list/read views, confirmation, atomic saves, TXT import/export and duplicate-safe merging | `quiet_places.tscn`, `village_journal.gd` | Local desktop persistence; no browser-save migration |
| Kind notes | Original eight English/Japanese notes, daily/kept choice, E next / K keep and source envelope/reader animation | `quiet_places.gd`, `assets/quiet/` | Local saved note; final subjective acceptance remains |
| Pond | Three swans, four ducks, eight trailing ducklings, eight fish, feed/arrival/hearts/reply/departure and 11-second cooldown | `pond_life.tscn`, `pond_life.gd` | Reusable crumb pouch as in source; local authority |
| Breathing | Calm 4–4–6, Box 4–4–4–4 and Slow 4–7–8, phase/count/rings/spirit, begin/pause/reset, reduced motion and exit | `quiet_places.gd`, `breath_orbit.gd` | Comprehensive game-wide reduced motion remains separate |
| Mac package | Universal local export, startup smoke, 1080p rendered starter | `export_presets.cfg`, `build/macos/` | Unsigned/unnotarized; broader standalone activity review remains |

Script names above are under `scenes/` unless another folder is shown. Full
ownership/source mappings are in [Architecture](docs/ARCHITECTURE.md).

## Work completed across the port

1. Established Godot and Forge editor/game control; reused source spirit/models/
   recordings without modifying the original project.
2. Converted generated world batches/materials, terrain/bridge sampling and
   environmental shaders into native saved resources.
3. Added native movement, horse motion, camera smoothing and obstruction handling.
4. Added local actor navigation/engagement, conversations, animals, dogs and flock.
5. Carried over starter/settings/map/inventory; refined UI using source DOM/CSS:
   forest/cream translucent panels, typography, 44 px buttons, padded real keycaps
   and press feedback. Fixed refreshes interrupting clicks and held-control release.
6. Added crops/farms, growth clocks, harvest/gifts, cooking/picnic and local saves;
   unified placement/contact calculations through WorldSurface.
7. Added seats/swings/race/cottage. Fixed seat picking, swing camera framing, race
   exit integration, horse dismount handling, focus preset scene ownership,
   bridge-window orientation and cottage audio.
8. Recorded native 1080p visuals/regressions, a continuous riding-input race win,
   and rebuilt/tested the local Mac export.
9. Completed writing/journal, kind notes and pond feeding/life/breathing; added
   both-facing swings/cushions, corrected Japanese glyphs and verified 1,370
   current steps across eight affected suites.

## Unfinished gameplay

Writing/journal, kind notes, pond life/feeding and breathing are implemented and
checked against the original source behavior. Match source behavior, keep
personal state local and author static UI in saved scenes.

| Work | Source starting points under `cosy-v1/features/` | Completion criteria |
| --- | --- | --- |
| Hearth / other place controls | `village/Activities.tsx`, `village/places.ts`, `village/audio.ts` | Reconcile place playback UI/animation with working Sound settings; audit tea/other source place entry/exit/UI for omissions |

External radio/media integration requires a separate scope decision; local music
playback does not establish those services. Backend/credential changes are not
part of this local-only port.

## Remaining parity and quality checks

- [x] Visit all 17 live map destinations and verify their native entry behavior (English).
- [ ] Complete the full Japanese destination/menu wrapping and keyboard-focus audit; new tea/music/bird/lookout labels are implemented.
- [ ] Review language popup, Japanese wrapping, focus navigation, long rebound
  keys, disabled controls and all menu/activity transitions at 1080p, including
  held-button release after application focus loss in every context.
- [x] Extend Reduce motion to outdoor spirit bob/fins, animal animation, wind/water/flame shaders, rain, camera easing, cooking/watering and cottage effects.
- [ ] Final subjective reduced-motion review of every animal/activity effect remains open.
- [ ] Review dialogue content, anchoring/fade/occlusion and animal cards in motion,
  including screen-edge cases; exact visual equality remains unaccepted.
- [ ] Walk the full map: joins, banks, bridges, dock, hills, planting clearances,
  seats and race gates. Compare render/collision/contact sound/destinations together.
- [ ] Finish standardizing remaining fixed anchors, including flock clearing and
  cottage fire restoration, without replacing authored intent.
- [ ] Review camera transitions across walking/horse/seat/swing/map/cottage,
  collision recovery and graphics modes.
- [ ] Listen to recordings, mix/crossfade/actions and completion on actual output
  hardware. Cottage shelter gain and the original indoor/weather low-pass are implemented.
- [ ] Compare lighting, water, wind/shadows and room motion in every weather mode.
- [ ] Verify all activities in the standalone Mac release, beyond the starter.

## Deferred platform and acceptance work

**Performance — active, resumed 2026-10-13.** The target is sustained 120+ FPS at 1920×1080 in
representative moving release scenes. Earlier short probes are below target and
are historical diagnostics. The opt-in harness now has 16 day/night/rain, moving and activity scenarios;
no current performance acceptance is claimed. See [Verification](docs/VERIFICATION.md).

**Browser — later milestone.** Choose a compatible renderer/export path, audit
shaders/materials/audio/input/persistence, create a local web export and test
supported browsers at 1080p. Mobile/touch is unverified. Deployment requires
explicit approval; browser support does not automatically add Worker/multiplayer.

**Distribution — not completed.** Signing/notarization and public delivery are
outside the local export. No published Godot release exists.

**Intentionally excluded:** custom editor/admin, Worker/multiplayer/shared chat,
source web app rewrites, live-world/save migration and deployment.

## Verified checkpoint and next handoff

[quiet-validation-final.json](evidence/quiet-validation-final.json) records eight
passing suites / 1,370 steps: journal/kind notes, pond, both-facing seats, menus,
focus, seating, garden/kitchen and NPCs. Lint: 32 scripts / 12 scenes, zero errors
or warnings. Twelve native 1920×1080 images cover writing/list/read/Japanese,
kind notes in both languages, pond breathing/feeding and both seating directions.

The user-requested seating follow-up chooses facing from the approach side and
exposes **T / Turn around** on all four swings and all five picnic cushions.
Turning preserves the real seat and pendulum; W/S pump relative to the chosen
facing. Ordinary backed benches keep their authored direction. E eating and F
basket actions remain independent. A regression caught and corrected picnic
access while movement is locked; seating and garden/kitchen reruns pass.

Source-derived behaviors include journal multiline/duplicate-preserving TXT
backup merge, English/Japanese phrases, family routes, the open-bank pond camera
and a single nearest-animal reply bubble. Native checks found and corrected paper
button contrast, Japanese font fallbacks and overlapping feeding labels.

The local Mac app was rebuilt; startup and its native 1080p starter render pass.
The exporter retains its known shutdown resource warnings; the app logs are clean.
Full standalone activity playthrough remains a separate verification boundary.

New saves are `user://journal-notes.json` and `user://kind-note.cfg`; fixtures use
separate files. Existing personal saves were preserved. Notes captured in images
are staged fixture content. Source project remains read-only; no Git writes or
deployment. FPS benchmarking was not run.

Resume with hearth/other place-control parity, then the existing remaining
quality checklist. Benchmark the release at native 1080p. Read [Verification](docs/VERIFICATION.md)
for exact evidence and package boundaries; saved scenes remain canonical.

## Live parity audit and release benchmark — 2026-10-13

The live hearth and bird destinations enter locked activities immediately; native
map travel previously omitted both. Source `Activities.tsx`, `activityScene.ts`,
`sharedActors.ts` and `audio.ts` also identify missing tea seating/cup moment,
hearth music/motes, indoor low-pass and rain gain, and outdoor reduced motion.
Current scope is local base-game behavior; external radio and shared-world
authority remain excluded. Current user saves were backed up to
`/tmp/hearthwillow-parity-20261013/userdata` before verification.

A five-view release probe and the broader moving/weather/activity benchmark
have completed. The first probe is exploratory; the deterministic run below
records renderer, graphics, resolution and movement verification.

Place implementation checkpoint (native behavior verified): saved native hearth
playback/soundtrack/mix access and 14 original-position motes; tea panel, original
extracted cup, mint/sip/steam moment and existing inventory/replies; bird panel
with flock state/disabled feeding; map activity entry for hearth/birds/garden.
Outdoor ambience has an authored low-pass bus and source 950/3500/6500 Hz
transitions, rain +.55 gain, weather-sensitive birds and cottage fire source.
Reduced-motion now reaches spirits/fins, scenery shaders, hearth and cottage
rituals; input buttons release held actions on application focus loss.

First valid release baseline: Mobile/M4, 1920×1080, VSync off, five orbiting-camera
views ×30 seconds +3 second warmup. Averages 84.1–142.0 FPS; p99 10.4–16.5 ms.
This does not meet sustained 120 FPS and does not yet cover walking/horse/weather/
activities. Raw report: `evidence/parity-baseline-fps.json`. Benchmark startup
now waits for world readiness; old early-start harness crashed on launch.


All 17 destinations were visited on https://cosy.sabarg.com/. The retained
accessibility snapshots are `evidence/live-destination-audit.json`; this audit
used ordinary travel/enter/leave controls and did not harvest shared crops or
send chat. Source inspection supplies the private/local behavior contracts.

| Live destination(s) | Verified native behavior |
| --- | --- |
| Focus cottage | Private timer/cat/room, enter/leave; sheltered outdoor sound and local fire anchor |
| Village hearth | Automatic music activity, pause/play, five soundtracks, sound settings, 14 motes |
| Willow pond | Automatic breathing activity, patterns and existing reusable-pouch pond feeding |
| Writing nook / Little postbox | Existing journal/kind-note activities and map transitions preserved |
| Kitchen garden | Automatic activity camera/lock, beds/tabs/basket, collapse and menu-safe return |
| Bird clearing | Automatic activity, flock phase, queued/served refusal and reusable crumb pouch |
| Meadow swings | Ground arrival; existing approach/seat/pump/facing behavior retained |
| Watch tower | Ground arrival, E ascent, bounded platform walking/look controls and safe descent |
| Willow circuit | Ground arrival; existing Rowan invitation/race retained |
| Owl grove / Garden kitchen / Picnic hill | Existing nearby feeding/cooking/basket controls retained |
| Carrot / Radish / Mint farms / Grazing field | Existing harvesting, animal/riding and forage controls retained |

Tea is reached by the garden basket/nearby terrace rather than a separate map
icon. Its camera/pose/entry and Luma staging were checked against the original
`ACTIVITY_STAGES`/`COMPANION_STAGES`; gifts and mint consumption were verified
locally. Followers now use the source side-by-side formation, single file through
narrow passages and the original fin-to-fin meeting pose. Dog tricks use original
7/5.2/3.2/3.8/4.2/4.6 second durations. Holding a dog in source is an interaction
reservation, not an exposed carry mechanic; no invented carry action was added.

Four native regression suites pass: live parity 165 steps, night/audio 67,
farm/horse 125 and NPCs 93 (450 total). The NPC fixture now explicitly chooses
English and follows the source reusable-pouch contract. All 15 changed gameplay
scripts have clean language-server diagnostics. Full Forge lint also scans
ignored build snapshots/reference scripts and reports 10 errors there; those
are outside the gameplay diagnostic scope.

The standalone Mobile/M4 release run completed: 16 scenarios, each 5-second
warmup plus 30 seconds measured, native 1920×1080, VSync off, Detailed/MSAA 4x,
normal motion and sound enabled. All four walking/horse cases verified actual
travel. Night walking averages 70.3 FPS, hearth 72.0 and lookout 59.5; every
scenario's p99 exceeds the 8.33 ms budget for 120 FPS. Cottage rain also records
a 1007.4 ms frame stall despite its 173.6 FPS average. Its cause is unresolved.
See `evidence/parity-current-fps.json` and the full table in docs/VERIFICATION.md.

`evidence/parity-current-source-hashes.json` identifies the measured snapshot in
`build/parity-current/Hearthwillow.app`. The final tea-button contrast,
reduced-motion flock poses and companion stopping/avoidance corrections followed
that run; current-source regressions and 1080p captures cover those corrections,
but the FPS report is not a measurement of that exact final source. A separate
local export is `build/parity-final/Hearthwillow.app`. That implementation pass did not replace or publish the public release. Physical listening, final visual acceptance, additional
camera-edge/language cases and sustained thermal testing remain open.


## GitHub preview 1 packaging — 2026-10-13

Both Mac universal and Windows x64 downloads now include the complete finished
night/audio and destination-parity source, including the final follow-up fixes.
The README contains direct download links for `v0.1.0-preview.1`. Both frozen-source
exports pass archive/pack checks; the extracted Mac app passes ad-hoc signature,
headless startup and native 1920×1080 Metal starter checks. The saved four-suite,
450-step gameplay evidence is retained. Windows runtime and another-Mac download
acceptance remain open; see docs/RELEASES.md for the exact package evidence.

# Port status and remaining work

Audited **2026-10-13** against current files and recorded evidence. Latest
activity implementation/tests: **2026-10-13**. Performance remains deferred.

Latest map/capture checkpoint: two passing native scenarios / 281 steps, lint
33 scripts / 12 scenes clean, three 1080p captures. Both map modes recorded zero
idle draw callbacks while actors continued moving. This is map update evidence;
the sustained FPS benchmark remains deferred. See docs/VERIFICATION.md.

Dock feeding now has its own nearby F/button path with no-pouch guidance, shared
cooldown and retained pouch. Three affected suites pass / 257 steps, including
actual elapsed-time feeding and existing pond/resident regressions. Native
captures are 1080p; final lint remains clean. The combined Mac app is rebuilt,
startup passes and packed script hashes match the verified source. See
docs/VERIFICATION.md for evidence and rollback.

## Download distribution — 2026-10-13

Public GitHub repository and Mac/Windows preview downloads are authorized. Mac
uses free ad-hoc signing without notarization; Windows targets x86_64 unsigned.
Packaging does not add multiplayer or resume the deferred FPS benchmark. See
[release preparation](docs/RELEASES.md) for artifacts and verification boundaries.

## Required outcome

Port the existing `cosy-v1` base game into Godot, Mac desktop first and browser
later. Run locally, preserve original art/dialogue/live-site controls, improve
inconsistent placement, and standardize shared rules. No custom editor, admin,
Worker or multiplayer. The ordinary Godot editor remains the authoring tool.

Active quality requirements: fluid camera, working NPCs and activities, polished
lighting/wind/sound, a better map and sustained 120+ FPS at 1080p. All visual tests
must use **1920×1080**. The next FPS benchmark is explicitly deferred by the user.

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
| Gifts | Luma gifts, original crop replies, mint tea and basket integration | `village_activities.gd` | Dedicated place UI is a separate parity item |
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

- [ ] Audit every base-game destination/activity against source in both languages.
- [ ] Review language popup, Japanese wrapping, focus navigation, long rebound
  keys, disabled controls and all menu/activity transitions at 1080p, including
  held-button release after application focus loss in every context.
- [ ] Complete reduced-motion parity. Experience now exposes a saved Reduce motion setting;
  new rituals/pond effects and the existing cat honor it. Comprehensive support
  across outdoor actors, weather and all feedback is not delivered.
- [ ] Review dialogue content, anchoring/fade/occlusion and animal cards in motion,
  including screen-edge cases; exact visual equality remains unaccepted.
- [ ] Walk the full map: joins, banks, bridges, dock, hills, planting clearances,
  seats and race gates. Compare render/collision/contact sound/destinations together.
- [ ] Finish standardizing remaining fixed anchors, including flock clearing and
  cottage fire restoration, without replacing authored intent.
- [ ] Review camera transitions across walking/horse/seat/swing/map/cottage,
  collision recovery and graphics modes.
- [ ] Listen to recordings, mix/crossfade/actions and completion on actual output
  hardware. Cottage shelter gain exists; source indoor low-pass parity is open.
- [ ] Compare lighting, water, wind/shadows and room motion in every weather mode.
- [ ] Verify all activities in the standalone Mac release, beyond the starter.

## Deferred platform and acceptance work

**Performance — user deferred.** The target is sustained 120+ FPS at 1920×1080 in
representative moving release scenes. Earlier short probes are below target and
are historical diagnostics. The opt-in harness needs longer/broader scenarios;
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
quality checklist. Keep the benchmark deferred. Read [Verification](docs/VERIFICATION.md)
for exact evidence and package boundaries; saved scenes remain canonical.

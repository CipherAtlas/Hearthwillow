# Hearthwillow-port

A local Godot port of the Three.js village in `/Users/sabar/Documents/cosy-v1`.
Mac desktop comes first; browser support follows later. Original scenery, spirit,
animal assets, recordings and live-site controls are the reference.

The game is playable, but the full base-game port and final acceptance remain in
progress. Writing/journal/kind-note and pond life/breathing are now implemented and
checked locally. The remaining place-controls audit is unfinished.
**Sustained 120+ FPS at 1920×1080 is not achieved or accepted.**
The user has deferred the next benchmark.

## Documentation

Updated **2026-10-13**. New native activity checks, facing controls and 1080p
captures are recorded in [Verification](VERIFICATION.md).

| Document | Purpose |
| --- | --- |
| [Status and remaining work](../MILESTONE.md) | Delivered systems, missing features, acceptance criteria and next work order |
| [Architecture](ARCHITECTURE.md) | Scene/script ownership, source mappings, standardized rules and saved data |
| [Development](DEVELOPMENT.md) | Running, authoring, conversion, export, troubleshooting and handoff |
| [Verification](VERIFICATION.md) | Test coverage, exact evidence, 1080p captures and acceptance limits |
| [AI working guide](../GODOT_AI.md) | Concise operating constraints for Godot Forge and future assistants |

## Run

Use Godot **4.7.2**, **Mobile** renderer. The tested Mac uses Metal on Apple M4.
Open `project.godot` and press Play, or launch the existing local build:

```sh
open /Users/sabar/Documents/ChatGPT/hearthwillow-port/build/macos/Hearthwillow-port.app
```

This is an unsigned local development export, not a notarized public distribution.
The game uses saved native resources: normal play does not require the original
web project, Node or a server. Godot may import assets on first editor opening.

## Playable systems

- Original generated village, terrain, paths/rivers, four bridges and collisions.
- Spirit movement, jumping, gliding, horse riding and eased camera follow/orbit.
- Nine residents; dogs, owls, pasture animals, hedgehog, horses and dove flock.
- Starter, guide, settings, sound mix, harvest basket and original map artwork.
- Destination-only map: 17 clear icons, stable labels, fit/zoom/pan and visitor marker; no NPC/animal/dog tracking.
- Seven garden beds, fifteen farm rows, countdowns, harvests and gifts.
- Four recipes, cooking, packing, serving and eating at picnic cushions.
- Seven seating locations / 17 seats; two swing pairs / four moving seats.
- Rowan's eight-gate race, countdown, rival, results and cancellation.
- Private focus cottage, persisted timer, breaks, original cat, petting and chime.
- Writing nook: protected journal input, past notes, reading, confirmed deletion,
  local persistence and compatible text backups/restores.
- Little postbox: original bilingual kind notes, keeping and animated reading.
- Pond: original swans/duck families/fish, dock F feeding and seated feeding, reusable crumb pouch, cooldown/thanks and breathing rhythms.
- Swings and picnic cushions: approach-side facing and T / Turn around.

“Playable” means native behavior and retained local checks exist. Full source
parity, subjective quality and platform/performance acceptance remain separate.

## Default controls

Settings can rebind keys; contextual keycaps show the active binding. The same
key can have a different meaning while seated, mounted or in the cottage.

| Context | Controls |
| --- | --- |
| Explore | WASD/arrows move; Shift dash; Space jump; G glide; R recover |
| Camera | Mouse look starts captured; Escape releases; click recaptures; wheel zooms. Map/settings release the pointer and recapture on close |
| Menus | M map; I harvest basket; comma Settings; O sound; Tab UI focus |
| Residents/animals | E interact; F chat/feed; follow the nearby action card |
| Dogs | P walk together; T Tricks; H send followers home; trick keys appear on the card |
| Benches/cushions | E sit, or click an individual bench seat; Escape stand |
| Bird bench | Sit, then F scatter crumbs |
| Swings | E mount; W/S pump in the direction you face; T Turn around; Space brake; Escape get off |
| Kitchen | 1–4 recipes; E packs the finished dish; card shows ingredient availability |
| Picnic | F Share & eat; E eats while seated; T Turn around; Escape closes an open basket first, then stands |
| Race | F talk to Rowan while unmounted, then C / Race me; WASD ride; Shift canter; F cancel; E dismount |
| Writing nook | E nearby / map entry; Cmd/Ctrl+Enter saves; Past notes opens list/read/backup controls; Escape leaves |
| Kind note | E Another note; K Keep; U hide/show controls; Escape leaves |
| Pond | At the dock, F feeds after asking Maple or Wren for crumbs. Seated: Space Begin/Pause; R Reset; 1/2/3 Calm/Box/Slow; F Feed; U hide/show; Escape leaves |
| Focus cottage | 1/2/3 presets; Space begin/pause/resume; R reset; B break after completion; U hide controls; E pet an asking cat; Escape leave |

## Scope and evidence

Nighttime now restores warm spirit bodies, painted window emission and lantern halos,
with only the two nearest lamp lights active. Walking and hoof sounds are quieter;
riding uses the original distinct hoof synthesis and stride/scale cadence. Native
night/audio and horse checks pass 192 steps; see [Verification](VERIFICATION.md)
for screenshots, the separate local test build and remaining acceptance limits.

The live destination audit now restores hearth music controls, tea with Luma,
bird feeding activity, automatic garden entry and the watchtower lookout. Source
companion staging/formation, reusable crumbs, indoor low-pass and outdoor reduced
motion are included. The 16-scenario native release FPS baseline is complete and falls short of
sustained 120 FPS. See [Milestone](../MILESTONE.md) and
[Verification](VERIFICATION.md) for the measured revision and open boundaries.

The original source is read-only. This port includes **no custom layout editor,
admin interface, Worker backend or multiplayer**. Outdoor simulation runs on this
machine; browser saved data and shared live-world state are not imported.

Visual checks use the native **1920×1080** render target. The quiet-activity checkpoint
records **eight passing playtests / 1,370 scenario steps** and clean lint of
32 scripts / 12 scenes. Twelve new activity captures are verified at 1920×1080;
the rebuilt Mac app passes startup and a separate 1080p starter render. The prior
13-suite leisure checkpoint remains retained separately. Read
[Verification](VERIFICATION.md) for evidence provenance and gaps.

The map/capture checkpoint adds two passing native scenarios / 281 steps and
clean lint of 33 scripts / 12 scenes. Three new captures are 1920×1080. Both map
modes recorded zero idle redraw callbacks while actors moved; this is not an FPS
benchmark. The dock-feeding checkpoint adds three passing scenarios / 257 steps, including
a complete meal on its actual clock. The local Mac app is rebuilt and passes startup; packed scripts match the
verified source. See Verification for exact evidence and remaining boundaries.

Start with [MILESTONE.md](../MILESTONE.md) before continuing. Saved scenes are
canonical: initial construction scripts can overwrite authoring and are not the
normal run/build workflow.

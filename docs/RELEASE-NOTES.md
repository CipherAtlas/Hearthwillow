# Hearthwillow 0.1.0 — early preview

A quiet village for wandering, animals, gardening, cooking, writing and focusing.
This preview includes the latest night lighting and audio, hearth music controls,
tea with Luma, the bird clearing, watchtower exploration, companion formations,
and reduced-motion refinements.
This is a local single-player preview with no account or game engine installation
required. It does not connect to the browser game's multiplayer world.

Download the ZIP for your computer, rather than the Source code archives:

- **Mac:** [Download for Apple Silicon / Intel](https://github.com/CipherAtlas/Hearthwillow/releases/download/v0.1.0-preview.1/Hearthwillow-macOS-universal.zip) — Apple Silicon and Intel. Extract,
  move Hearthwillow.app to Applications, and open it. Free ad-hoc signing, without
  Apple notarization. If blocked, try opening once, then System Settings → Privacy
  & Security → Open Anyway.
- **Windows x64:** [Download for Intel / AMD 64-bit](https://github.com/CipherAtlas/Hearthwillow/releases/download/v0.1.0-preview.1/Hearthwillow-Windows-x64.zip) — Intel/AMD 64-bit. Extract all
  files and run Hearthwillow.exe. Unsigned and experimental; not yet tested on a
  Windows PC. SmartScreen may warn; More info → Run anyway may be available.
  Smart App Control or managed security settings can block unsigned apps.

WASD/arrows move, mouse looks, Escape releases the mouse, E/F perform nearby
actions, M opens the map, comma opens Settings, and O turns sound on.

Saves remain on your computer. The full port and graphics/performance refinements
are in progress; there is no guaranteed frame rate. SHA256SUMS.txt contains the
download checksums. Licenses and credits are included in both ZIPs.

The latest saved native regression evidence passes four suites (450 steps).
Both release packs and the Mac startup/signature are checked separately. Windows
runtime testing remains open. An earlier M4/Metal benchmark did not meet the
120 FPS target across all scenarios; final follow-up fixes were not benchmarked.

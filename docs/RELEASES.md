# Download builds

GitHub Actions now builds both downloads on main pushes and publishes verified
version-tag builds. Follow [DEPLOYMENT.md](../DEPLOYMENT.md) for the automated
workflow and manual fallback. The commands below describe local packaging.

Build with **Godot 4.7.2 stable** on macOS. Install the matching official export
templates for macOS and Windows x86_64; no paid signing certificate is required.

```sh
python3 scripts/package_release.py --tag v0.1.0-preview.2
python3 scripts/verify_release.py
```

The script exports both presets, verifies the Mac signature, includes third-party
notices and player instructions, and creates these GitHub release assets:

- `build/releases/Hearthwillow-macOS-universal.zip`
- `build/releases/Hearthwillow-Windows-x64.zip`
- `build/releases/SHA256SUMS.txt`

`Mac desktop` uses a universal Apple Silicon/Intel binary, the bundle identifier
`com.sabarg.hearthwillow`, and Godot's built-in ad-hoc signer. Notarization is
disabled. `Windows x64` uses an unsigned x86_64 executable and a separate game
pack. Both use the existing Mobile renderer. The Windows export can be made on
Mac; running it still requires Windows.

The internal project name remains `Hearthwillow-port` to preserve the existing
Godot user-data directory. Packaging does not bundle any user saves. The earlier
local app in `build/macos/` remains available as a rollback.

The large intermediate `assets/village/geometry.bin` stays local and is ignored
by Git and exports. The authored native meshes/scenes are included; this extraction
file is only needed when deliberately rebuilding the village from its source.

Use the ZIPs as release assets, rather than adding binaries to Git. The initial
release was an early preview; automated release notes come from
[the release template](RELEASE-TEMPLATE.md).
Publish only after explicitly choosing to publish. GitHub's automatic source ZIPs
are for developers and are not playable downloads.

## Verification

For concurrent work, export from a frozen source copy. The packaging script
checks scene/shader/settings hashes before and after export and refuses to finish
if those files change. It writes `build/releases/source-hashes.json` for traceability.

Before uploading, verify the archives extract, the Mac app signature remains
valid after extraction, its binary contains arm64 and x86_64, and the Windows
executable is PE x86_64. Check both game packs contain the runtime data and
required resources. Run the Mac app with its real renderer as well as a startup
smoke check. Windows gameplay, graphics, audio, saves, and download security
prompts require testing on a Windows PC. Mac Gatekeeper download acceptance also
needs testing through an actual browser download on another Mac.

Startup, archive and signature checks are not performance or full playthrough
acceptance. The latest separately recorded M4 benchmark and its source-snapshot
boundary are documented in [verification](VERIFICATION.md); it does not establish
performance for the exact final preview package.

## Initial preview preparation — 2026-10-13

Both ZIPs pass integrity and SHA-256 checks. The Mac signature verifies after
extraction and contains arm64/x86_64; its release startup and a 1920×1080 Metal
starter render pass without runtime errors. Both packs load required scene
resources and 11 runtime data files; all packed gameplay scripts match the frozen
source. The Windows executable is PE32+ x86-64. Windows runtime and another-Mac
browser-download acceptance remain untested. The initial snapshot was saved as
a draft; the validation below covers its rebuilt replacement assets.

See [the release report](../evidence/release-preparation-20261013.json),
[source hashes](../evidence/release-source-hashes-20261013.json), and
[the release starter](../evidence/release-starter-1080p.png). Exporter shutdown
still reports the previously recorded retained ObjectDB/resources, while the
release runtime logs are clean. The starter movie frame is not an FPS result.

## Preview 1 final release validation — 2026-10-13

`v0.1.0-preview.1` includes all completed night/audio and destination-parity
changes, including the final tea contrast, reduced-motion flock and companion
corrections. Both ZIPs were rebuilt from the same frozen staged source, replacing
the earlier draft downloads. The [README](../README.md) links directly to each ZIP.

The rebuilt archives pass integrity checks. The extracted universal Mac app has
a valid ad-hoc signature, starts cleanly, and renders its starter at 1920×1080
with Metal on Apple M4. Both packs match 52 source/data hashes and load seven
required resources, including the tea cup, companion stages, lookout and audio
bus layout. All 101 scene/shader/settings hashes match the staged source. The full runtime
source audit compares 3,316 files: 3,315 match byte-for-byte; Godot normalizes the
audio bus resource while exporting, and both packed bus/filter settings match
the authored values.

The four saved gameplay suites pass 450 steps; those results are reused here.
Windows gameplay and another-Mac download acceptance remain untested. The movie
capture verifies startup rendering, not performance. See [validation](../evidence/preview1-release-validation.json),
[source hashes](../evidence/preview1-source-hashes.json),
[checksums](../evidence/preview1-SHA256SUMS.txt) and
[starter capture](../evidence/preview1-starter-1080p.png).

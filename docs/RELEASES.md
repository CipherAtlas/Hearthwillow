# Download builds

Build with **Godot 4.7.2 stable** on macOS. Install the matching official export
templates for macOS and Windows x86_64; no paid signing certificate is required.

```sh
python3 scripts/package_release.py
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
release is an early preview; prepare its notes from [release notes](RELEASE-NOTES.md).
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

This work does not resume the deferred sustained FPS benchmark. Startup, archive,
and signature checks are not performance or full playthrough acceptance.

## Initial preview preparation — 2026-10-13

Both ZIPs pass integrity and SHA-256 checks. The Mac signature verifies after
extraction and contains arm64/x86_64; its release startup and a 1920×1080 Metal
starter render pass without runtime errors. Both packs load required scene
resources and 11 runtime data files; all packed gameplay scripts match the frozen
source. The Windows executable is PE32+ x86-64. Windows runtime and another-Mac
browser-download acceptance remain untested. The initial release is a draft.

See [the release report](../evidence/release-preparation-20261013.json),
[source hashes](../evidence/release-source-hashes-20261013.json), and
[the release starter](../evidence/release-starter-1080p.png). Exporter shutdown
still reports the previously recorded retained ObjectDB/resources, while the
release runtime logs are clean. The starter movie frame is not an FPS result.

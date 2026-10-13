# Deploying Hearthwillow

This guide is for agents preparing and publishing the downloadable Godot game at
[CipherAtlas/Hearthwillow](https://github.com/CipherAtlas/Hearthwillow). Deployment
currently means a **manual GitHub Release** with a Mac universal ZIP, a Windows
x64 ZIP, and checksums. There is no release CI workflow. This process does not
deploy `cosy.sabarg.com`, Cloudflare services, or a browser build.

## Before starting

Read applicable `AGENTS.md` instructions, [GODOT_AI.md](GODOT_AI.md),
[MILESTONE.md](MILESTONE.md), [development](docs/DEVELOPMENT.md),
[verification](docs/VERIFICATION.md), and [build details](docs/RELEASES.md).
Inspect Git status, the actual source changes, origin, and existing releases.

```sh
git status --short
git diff --stat
git diff --check
git remote -v
gh release list --repo CipherAtlas/Hearthwillow
```

A request to prepare downloads authorizes preparation; publishing needs explicit
user authorization. Git staging, commits and pushes also need authorization under
the applicable instructions. Reuse authorization already given for the task.
Include all changes when the user requests that scope; otherwise preserve
unrelated work. Never reset, stash or discard another agent's changes to release.
Do not add CI, paid signing, credentials or infrastructure changes implicitly.

For an ordinary update, choose a **new** tag, such as `v0.1.0-preview.2` after
preview 1. Inspect existing tags before choosing it. Keep published tags and
assets intact; replacing a live release requires explicit authorization. Replacing
assets on an authorized, unpublished draft is part of preparing that draft.

## Build tools and configuration

Package on macOS with these tools available:

- Godot **4.7.2 stable** on `PATH`, with matching official export templates.
  The current local executable is `/opt/homebrew/bin/godot`.
- Python **3.11 or newer**; packaging uses `hashlib.file_digest`.
- macOS `ditto`, `codesign`, Git, and an authenticated `gh` CLI for publishing.

```sh
godot --version
python3 --version
gh auth status
```

The local template directory is
`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`.
It must contain `macos.zip` and `windows_release_x86_64.exe`. Use official
templates for the exact engine version. An engine upgrade also requires changing
the version check in `scripts/package_release.py` and revalidating both platforms;
it is a separate change, not a workaround for an export failure.

`export_presets.cfg` defines:

| Preset | Output | Signing |
| --- | --- | --- |
| `Mac desktop` | `Hearthwillow.app`, arm64 + x86_64 | Godot built-in ad-hoc; no notarization |
| `Windows x64` | `Hearthwillow.exe` + `Hearthwillow.pck` | Unsigned |

Both use the existing Mobile renderer. Preserve `com.sabarg.hearthwillow` and the
internal project name `Hearthwillow-port`; changing the latter changes the default
user-data directory. Ad-hoc signing is free and does **not** bypass Gatekeeper.
Keep accurate Mac installation instructions and Windows unsigned-app warnings.

Before the source commit, update version metadata in both presets when the app
version changes. Update the README release/tag links and
[release notes](docs/RELEASE-NOTES.md) for the chosen preview. Preview suffixes
belong in the Git tag/title; the current platform version fields are numeric.
Keep third-party notices, player instructions and all required runtime JSON/bin
data in the packages. Review export filters whenever adding runtime files.

## Freeze the source and build both platforms

Audit the files selected for the release, including untracked files, asset rights
and potential secrets. Stage only the authorized scope, review the staged diff,
commit it, and record its full SHA. Do not commit `.godot/`, build outputs,
templates, user saves or the intermediate `assets/village/geometry.bin`.
The saved native scenes/meshes are the build source. Do not rerun conversion or
scene initialization scripts as a release step.

Build from a fresh copy of that commit, especially while other agents are editing
the checkout. Run the following in the repository root after the source commit;
keep these variables for the remaining examples:

```sh
set -euo pipefail
release_repo="CipherAtlas/Hearthwillow"
release_tag="v0.1.0-preview.2" # Example: choose an unused tag for this release.
release_commit="$(git rev-parse HEAD)"
release_repo_root="$(pwd -P)"
mkdir -p "$release_repo_root/build"
release_source="$(mktemp -d "$release_repo_root/build/release-XXXXXX")"
git archive "$release_commit" | tar -x -C "$release_source"
godot --headless --editor --path "$release_source" --import \
  > "$release_source/import.log" 2>&1
python3 "$release_source/scripts/package_release.py"
release_output="$release_source/build/releases"
```

A clean import is preferable to copying a potentially changing editor cache.
Stop on command failures and inspect the import/export logs. Use a new directory
for every attempt so stale files cannot enter the ZIPs.

The script creates:

- `Hearthwillow-macOS-universal.zip`
- `Hearthwillow-Windows-x64.zip`
- `SHA256SUMS.txt`
- `source-hashes.json`, `mac-export.log` and `windows-export.log` for evidence.

Only the first three are public release assets. The script hashes scenes,
shaders, `project.godot` and `export_presets.cfg` before/after export. That check
does not cover every asset; the frozen commit is the primary source boundary.
Audit remaining runtime files against that commit. Godot may normalize
`default_bus_layout.tres` by adding a UID/default flags: verify equivalent packed
bus/effect settings rather than silently accepting arbitrary differences.

## Verify the exact downloads

Complete the relevant gameplay scenarios and compiler checks described in
`docs/DEVELOPMENT.md`. Reuse saved evidence only when its source and scope apply;
state which checks were reused. Build success alone does not verify gameplay.

Check both ZIPs with Python `zipfile.ZipFile.testzip()` and confirm each contains
`START-HERE.txt`, license notices and its complete platform payload. Verify the
checksums **from the output directory**:

```sh
(cd "$release_output" && shasum -a 256 -c SHA256SUMS.txt)
release_checks="$(mktemp -d "$release_repo_root/build/release-checks-XXXXXX")"
ditto -x -k "$release_output/Hearthwillow-macOS-universal.zip" \
  "$release_checks/mac"
ditto -x -k "$release_output/Hearthwillow-Windows-x64.zip" \
  "$release_checks/windows"
release_app="$release_checks/mac/Hearthwillow.app"
codesign --verify --deep --strict "$release_app"
codesign -dv "$release_app"
file "$release_app/Contents/MacOS/Hearthwillow-port" \
  "$release_checks/windows/Hearthwillow.exe"
```

Expect `Signature=adhoc`, Mac arm64/x86_64 slices and a Windows PE32+ x86-64
executable. Keep the `.pck` beside the Windows executable and package every
needed DLL. macOS tests of that pack do not establish Windows runtime support.

Audit **both extracted packs** with the Godot editor executable. Create an audit
helper under the ignored `build/` directory; old local helpers are not guaranteed
to exist in a fresh clone. Its checks should fail with a nonzero exit code and:

- Load `main.tscn`, `menus.tscn`, `quiet_places.tscn`, `pond_life.tscn`,
  `tower_lookout.tscn`, `assets/quiet/tea-cup.glb` and `default_bus_layout.tres`.
- Check required FileAccess data: `assets/quiet/kind-notes.json`,
  `assets/quiet/companion-stages.json`, `assets/rest/rest-data.json`, village
  `world-data.json`, `map-destinations.json`, `navigation.json`, `navigation.bin`,
  `floor-heights.bin` and all four `bridge-floor-0.bin` through `bridge-floor-3.bin`.
- Compare packed `.gd`/`.gdshader` hashes to `source-hashes.json` and runtime data
  hashes to the frozen source. Update the list when gameplay adds dependencies.
- Verify packed credits/notices and exclusion of development documents/images.
- Verify the Outdoor audio bus routes to Master at 0 dB with its enabled 6500 Hz
  low-pass; mute, solo and bypass are off in the authored default layout.

Run from an **isolated empty project directory**, otherwise resources may fall
back to checkout files and make the audit misleading. Substitute the absolute
path of the helper you created:

```sh
mkdir -p "$release_checks/isolated"
godot --headless --path "$release_checks/isolated" \
  --main-pack "$release_app/Contents/Resources/Hearthwillow-port.pck" \
  --script /absolute/path/to/audit-pack.gd --quit-after 3
godot --headless --path "$release_checks/isolated" \
  --main-pack "$release_checks/windows/Hearthwillow.pck" \
  --script /absolute/path/to/audit-pack.gd --quit-after 3
```

Back up existing user data before testing behavior that can write saves. On this
Mac it is under `~/Library/Application Support/Godot/app_userdata/Hearthwillow-port`.
Use disposable profiles where possible; never ship test saves. Then check the
actual extracted Mac release executable:

```sh
"$release_app/Contents/MacOS/Hearthwillow-port" --headless --quit-after 30 \
  > "$release_checks/mac-startup.log" 2>&1
"$release_app/Contents/MacOS/Hearthwillow-port" \
  --write-movie "$release_checks/starter.avi" --quit-after 120 \
  > "$release_checks/mac-render.log" 2>&1
```

Check clean runtime logs, the actual Metal renderer and a drawn 1920×1080 frame;
allow startup to finish before selecting a frame. Movie recording forces a fixed
timestep and is **not an FPS benchmark**. Normal native play is needed for input,
motion, audio, saves and visual acceptance. The release binary does not support
the editor's `--path`/`--script` overrides; use the editor executable for pack audits.

Previously observed exporter shutdown warnings about retained ObjectDB/resources
are recorded in `docs/RELEASES.md`. They do not excuse new parse/export/runtime
errors. Windows gameplay needs a Windows PC; browser-download Gatekeeper behavior
needs another Mac. Keep untested boundaries explicit in the release notes.

Save logs, hashes, checksums and relevant native captures in `evidence/`, and update
the release/verification documents. Commit authorized evidence/docs before tagging.
If those commits only add files excluded from export, the verified binaries can
be retained after confirming runtime source/settings are unchanged. Any runtime
change requires rebuilding and rechecking both packages. Set `release_commit` to
the final commit containing all release changes, then push it to `origin/main`.

## Upload a draft, then publish

Use the frozen build's output paths; `build/releases/` in the active checkout may
still contain an older export. Do not use `/releases/latest` for preview links;
link to the specific prerelease tag in the README and release notes.

With the final source SHA pushed and the chosen tag unused:

```sh
release_commit="$(git rev-parse HEAD)"
gh release create "$release_tag" --repo "$release_repo" \
  --target "$release_commit" --draft --prerelease --latest=false \
  --title "Hearthwillow ${release_tag#v} — Early preview" \
  --notes-file "$release_repo_root/docs/RELEASE-NOTES.md" \
  "$release_output/Hearthwillow-macOS-universal.zip" \
  "$release_output/Hearthwillow-Windows-x64.zip" \
  "$release_output/SHA256SUMS.txt"
gh release view "$release_tag" --repo "$release_repo" \
  --json isDraft,isPrerelease,targetCommitish,assets,url
```

For an existing authorized draft, use `gh release upload ... --clobber` to replace
its three assets and `gh release edit ... --target ... --notes-file ...` to update
its metadata. Recheck that it is still a draft before replacing anything.

Before publishing, compare each remote asset's name, size and SHA-256 `digest`
against the exact local file, including `SHA256SUMS.txt`. If GitHub does not return
a digest, download that asset into the verification directory and hash it locally.
Confirm the draft target is the final source SHA and notes/README use the chosen
tag. Once publication is authorized and these checks pass:

```sh
gh release edit "$release_tag" --repo "$release_repo" \
  --target "$release_commit" --draft=false --prerelease --latest=false \
  --notes-file "$release_repo_root/docs/RELEASE-NOTES.md"
```

## Verify publication and hand off

Confirm `isDraft=false`, `isPrerelease=true`, the repository is public, and the
remote tag resolves to `release_commit`. Dereference annotated tags if necessary.
Recheck all three remote asset hashes and that the remote README matches the
committed file. Verify both download URLs publicly resolve with HTTP 200:

```sh
curl -f -sS -I -L --max-time 30 -o /dev/null -w '%{http_code}\n' \
  "https://github.com/$release_repo/releases/download/$release_tag/Hearthwillow-macOS-universal.zip"
curl -f -sS -I -L --max-time 30 -o /dev/null -w '%{http_code}\n' \
  "https://github.com/$release_repo/releases/download/$release_tag/Hearthwillow-Windows-x64.zip"
```

Report the public release and direct downloads, final source SHA, checks actually
run, reused evidence and remaining platform/performance limits. Inspect Git status
again; disclose work that arrived after the frozen snapshot rather than silently
claiming it was packaged. Preserve the previous release and user-data backups for
rollback. A correction should normally be a new preview tag, with README links
moved to it; do not rewrite a published tag or silently replace its binaries.

## Published baseline

As verified on **2026-10-13**, [v0.1.0-preview.1](https://github.com/CipherAtlas/Hearthwillow/releases/tag/v0.1.0-preview.1)
is a public prerelease targeting `0d5657a3a188ebdb7018d0d1bdf2e23243cc01a0`.
[Its validation report](evidence/preview1-release-validation.json) and
[checksums](evidence/preview1-SHA256SUMS.txt) identify the shipped downloads.
Mac archive/signature/Metal startup and both pack audits passed. Four saved suites
passed 450 steps; those gameplay results were reused for publication. Windows
runtime and another-Mac download acceptance remain untested. The exact final
package was not benchmarked, and the earlier M4 run did not meet 120 FPS in every
scenario. Refresh this baseline from GitHub and current evidence before the next
release; historical checks do not certify a newer build.

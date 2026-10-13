#!/usr/bin/env python3
"""Export and package the Mac and Windows previews using existing Godot templates."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "build/releases"


def run(*args, log=None):
    if log:
        with log.open("w") as stream:
            subprocess.run(args, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, check=True)
    else:
        subprocess.run(args, cwd=ROOT, check=True)


def add_notices(folder):
    notices = folder / "Licenses"
    notices.mkdir(exist_ok=True)
    for source in (
        "assets/village/CREDITS.txt", "assets/fonts/Outfit-OFL.txt",
        "assets/ui/Phosphor-LICENSE.txt", "assets/audio/Salamander-LICENSE.txt",
        "assets/licenses/Godot-LICENSE.txt", "assets/licenses/Godot-COPYRIGHT.txt",
        "addons/godot_forge/LICENSE", "THREE-LICENSE.txt",
    ):
        filename = "Godot-Forge-LICENSE.txt" if source.endswith("godot_forge/LICENSE") else Path(source).name
        shutil.copy2(ROOT / source, notices / filename)


def main():
    godot = shutil.which("godot")
    if not godot:
        raise SystemExit("Godot 4.7.2 must be on PATH, with Mac and Windows x64 export templates installed.")
    if not subprocess.check_output([godot, "--version"], text=True).startswith("4.7.2.stable"):
        raise SystemExit("This release requires Godot 4.7.2 stable and matching export templates.")
    if not shutil.which("ditto") or not shutil.which("codesign"):
        raise SystemExit("Package these downloads on macOS: ditto preserves the app bundle permissions.")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (ROOT / "build/.gdignore").touch()
    source_hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                     for folder in ("scenes", "assets/shaders")
                     for p in (ROOT / folder).rglob("*") if p.is_file()}
    for name in ("project.godot", "export_presets.cfg"):
        source_hashes[name] = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
    mac = OUTPUT / "macos"
    windows = OUTPUT / "windows"
    mac.mkdir(parents=True, exist_ok=True)
    windows.mkdir(parents=True, exist_ok=True)
    app = mac / "Hearthwillow.app"
    exe = windows / "Hearthwillow.exe"
    run(godot, "--headless", "--path", str(ROOT), "--export-release", "Mac desktop", str(app), log=OUTPUT / "mac-export.log")
    run("codesign", "--verify", "--deep", "--strict", str(app))
    run(godot, "--headless", "--path", str(ROOT), "--export-release", "Windows x64", str(exe), log=OUTPUT / "windows-export.log")
    add_notices(mac)
    add_notices(windows)
    (mac / "START-HERE.txt").write_text(
        "Hearthwillow — early single-player preview\n\n"
        "Drag Hearthwillow.app into Applications and open it.\n"
        "Ad-hoc signed, not notarized: if macOS blocks it, try opening once,\n"
        "then System Settings > Privacy & Security > Open Anyway.\n"
        "WASD: move; mouse: look; Escape: release mouse; E/F: nearby actions;\n"
        "M: map; comma: settings; O: sound. Saves stay on this computer.\n"
        "https://github.com/CipherAtlas/Hearthwillow\n", encoding="utf-8")
    (windows / "START-HERE.txt").write_text(
        "Hearthwillow — experimental Windows x64 preview\n\n"
        "Extract all files into one folder, then open Hearthwillow.exe.\n"
        "Keep the .pck and any .dll files beside the executable.\n"
        "Unsigned; not yet tested on a Windows PC. SmartScreen may warn;\n"
        "where permitted, More info > Run anyway opens it. Smart App Control\n"
        "or managed security settings may block unsigned apps.\n"
        "WASD: move; mouse: look; Escape: release mouse; E/F: nearby actions;\n"
        "M: map; comma: settings; O: sound. Saves stay on this computer.\n"
        "https://github.com/CipherAtlas/Hearthwillow\n", encoding="utf-8")
    mac_zip = OUTPUT / "Hearthwillow-macOS-universal.zip"
    # mac contains the app plus player instructions and license notices.
    run("ditto", "-c", "-k", "--sequesterRsrc", str(mac), str(mac_zip))
    windows_zip = OUTPUT / "Hearthwillow-Windows-x64.zip"
    with zipfile.ZipFile(windows_zip, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(windows.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(windows))
    for name, digest in source_hashes.items():
        if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != digest:
            raise SystemExit(f"Source changed while exporting: {name}. Rebuild from a frozen checkout.")
    (OUTPUT / "source-hashes.json").write_text(json.dumps(source_hashes, indent=2)+"\n")
    checksums = []
    for path in (mac_zip, windows_zip):
        with path.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        checksums.append(f"{digest}  {path.name}\n")
        print(f"Packaged {path.name}: {path.stat().st_size:,} bytes")
    (OUTPUT / "SHA256SUMS.txt").write_text("".join(checksums), encoding="utf-8")


if __name__ == "__main__":
    main()

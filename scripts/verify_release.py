#!/usr/bin/env python3
"""Verify both packaged downloads on macOS, including isolated Godot pack audits."""
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "build/releases"
DATA = [
    "assets/quiet/kind-notes.json", "assets/quiet/companion-stages.json",
    "assets/rest/rest-data.json", "assets/village/world-data.json",
    "assets/village/map-destinations.json", "assets/village/navigation.json",
    "assets/village/navigation.bin", "assets/village/floor-heights.bin",
] + [f"assets/village/bridge-floor-{i}.bin" for i in range(4)]
RESOURCES = [
    "scenes/main.tscn", "scenes/menus.tscn", "scenes/quiet_places.tscn",
    "scenes/pond_life.tscn", "scenes/tower_lookout.tscn",
    "assets/quiet/tea-cup.glb", "default_bus_layout.tres",
]


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def run(args, log, cwd):
    with log.open("w") as stream:
        subprocess.run(args, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT,
                       check=True, timeout=180)
    result = log.read_text()
    require("SCRIPT ERROR:" not in result and "ERROR:" not in result,
            f"Runtime error; inspect {log}")
    return result


def main():
    expected_archives = {"Hearthwillow-macOS-universal.zip", "Hearthwillow-Windows-x64.zip"}
    checksums = {}
    for line in (OUTPUT / "SHA256SUMS.txt").read_text().splitlines():
        digest, name = line.split("  ", 1)
        require(name not in checksums, "Duplicate checksum entry")
        checksums[name] = digest
    require(set(checksums) == expected_archives, "Expected exactly two game ZIP checksums")
    checks = Path(tempfile.mkdtemp(prefix="release-checks-", dir=ROOT / "build"))
    for name, digest in checksums.items():
        archive = OUTPUT / name
        with archive.open("rb") as stream:
            require(hashlib.file_digest(stream, "sha256").hexdigest() == digest, f"Checksum: {name}")
        with zipfile.ZipFile(archive) as contents:
            require(contents.testzip() is None, f"ZIP corruption: {name}")
            require("START-HERE.txt" in contents.namelist(), f"Missing instructions: {name}")
            for notice in ("Godot-LICENSE.txt", "Godot-COPYRIGHT.txt", "CREDITS.txt",
                           "Godot-Forge-LICENSE.txt", "THREE-LICENSE.txt", "Outfit-OFL.txt",
                           "Phosphor-LICENSE.txt", "Salamander-LICENSE.txt"):
                require(f"Licenses/{notice}" in contents.namelist(), f"Missing {notice}: {name}")
        destination = checks / ("macos" if "macOS" in name else "windows")
        subprocess.run(["ditto", "-x", "-k", str(archive), str(destination)], check=True)
    app = checks / "macos/Hearthwillow.app"
    binary = app / "Contents/MacOS/Hearthwillow-port"
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    signature = subprocess.run(["codesign", "-dv", str(app)], capture_output=True, text=True, check=True)
    require("Signature=adhoc" in signature.stderr, "Expected an ad-hoc Mac signature")
    architectures = subprocess.check_output(["lipo", "-archs", str(binary)], text=True).split()
    require(set(architectures) == {"arm64", "x86_64"}, "Expected both Mac architectures")
    with (checks / "windows/Hearthwillow.exe").open("rb") as exe:
        require(exe.read(2) == b"MZ", "Windows DOS header")
        exe.seek(0x3C)
        offset = struct.unpack("<I", exe.read(4))[0]
        exe.seek(offset)
        require(exe.read(4) == b"PE\0\0", "Windows PE header")
        require(struct.unpack("<H", exe.read(2))[0] == 0x8664, "Expected Windows x64")
        exe.seek(offset + 24)
        require(struct.unpack("<H", exe.read(2))[0] == 0x20B, "Expected Windows PE32+")

    hashes = json.loads((OUTPUT / "source-hashes.json").read_text())
    packed = {name: digest for name, digest in hashes.items()
              if name.endswith((".gd", ".gdshader"))}
    packed.update({name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in DATA})
    notices = ["assets/licenses/Godot-LICENSE.txt", "assets/licenses/Godot-COPYRIGHT.txt",
               "assets/village/CREDITS.txt", "assets/fonts/Outfit-OFL.txt"]
    packed.update({name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in notices})
    helper = checks / "audit-pack.gd"
    helper.write_text("""extends SceneTree
var failed := false
func check(ok: bool, message: String) -> void:
 if not ok:
  push_error(message)
  failed = true
func _init() -> void:
""" + " var expected = " + json.dumps(packed) + """
 for path in expected:
  check(FileAccess.get_sha256("res://"+path)==expected[path],"Packed hash differs: "+path)
""" + " for path in " + json.dumps(RESOURCES) + """:
  check(ResourceLoader.load("res://"+path)!=null,"Missing resource: "+path)
 var layout: AudioBusLayout = load("res://default_bus_layout.tres")
 AudioServer.set_bus_layout(layout)
 check(AudioServer.bus_count==2,"Audio bus count")
 check(AudioServer.get_bus_name(0)=="Master" and AudioServer.get_bus_name(1)=="Outdoor","Audio bus names")
 check(AudioServer.get_bus_send(1)=="Master" and AudioServer.get_bus_volume_db(1)==0.0,"Outdoor routing/gain")
 check(not AudioServer.is_bus_mute(1) and not AudioServer.is_bus_solo(1) and not AudioServer.is_bus_bypassing_effects(1),"Outdoor flags")
 var effect := AudioServer.get_bus_effect(1,0) as AudioEffectLowPassFilter
 check(effect!=null and effect.cutoff_hz==6500.0 and AudioServer.is_bus_effect_enabled(1,0),"Outdoor filter")
 check(not FileAccess.file_exists("res://README.md"),"Development README included")
 check(not ResourceLoader.exists("res://docs/images/gameplay.png"),"Documentation image included")
 print("Pack audit passed=",not failed)
 quit(1 if failed else 0)
""")
    isolated = checks / "isolated"
    isolated.mkdir()
    for platform, pack in [
        ("macos", app / "Contents/Resources/Hearthwillow-port.pck"),
        ("windows", checks / "windows/Hearthwillow.pck"),
    ]:
        result = run(["godot", "--headless", "--path", str(isolated), "--main-pack", str(pack),
                      "--script", str(helper), "--quit-after", "3"],
                     OUTPUT / f"{platform}-pack-audit.log", isolated)
        require("Pack audit passed=true" in result, f"Incomplete {platform} pack audit")
    run([str(binary), "--headless", "--quit-after", "30"], OUTPUT / "mac-startup.log", isolated)
    (OUTPUT / "verification.json").write_text(json.dumps({
        "archives": checksums,
        "mac_signature": "adhoc",
        "mac_architectures": architectures,
        "windows_binary": "PE32+ x86-64",
        "packed_hashes_per_platform": len(packed),
        "loaded_resources_per_platform": len(RESOURCES),
        "mac_headless_startup": "passed",
        "limitations": ["Headless checks do not verify graphics, gameplay, audio or performance.",
                        "Windows native startup is checked separately by GitHub Actions."],
    }, indent=2)+"\n")
    print("Both release downloads verified; evidence:", OUTPUT)


if __name__ == "__main__":
    main()

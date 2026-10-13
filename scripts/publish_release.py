#!/usr/bin/env python3
"""Publish verified GitHub release assets and refresh the README download links."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
TAG = re.compile(r"v((?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*))(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?")
ASSETS = ("Hearthwillow-macOS-universal.zip", "Hearthwillow-Windows-x64.zip", "SHA256SUMS.txt")


def gh(*args):
    return subprocess.check_output(["gh", *args], text=True).strip()


def release_key(tag):
    match = TAG.fullmatch(tag)
    if not match:
        raise ValueError("Use vMAJOR.MINOR.PATCH with an optional prerelease suffix.")
    core = tuple(int(part) for part in match[1].split("."))
    suffix = tuple((0, int(part)) if part.isdigit() else (1, part)
                   for part in (match[2] or "").split("."))
    return core + (0, suffix) if match[2] else core + (1, ())


def refresh_readme(repository, tag):
    endpoint = f"repos/{repository}/contents/README.md"
    for attempt in range(3):
        current = json.loads(gh("api", endpoint, "-f", "ref=main", "--method", "GET"))
        text = base64.b64decode(current["content"]).decode()
        base = f"https://github.com/{repository}/releases"
        pinned = re.search(re.escape(base) + r"/tag/([^\s)]+)", text)
        if pinned and release_key(pinned[1]) > release_key(tag):
            print("README already points to a newer version; keeping its links.")
            return
        updated = re.sub(re.escape(base) + r"/(tag|download)/[^/\s)]+",
                         lambda match: f"{base}/{match[1]}/{tag}", text)
        updated = re.sub(r"Download \*\*[^*]+\*\* from",
                         lambda _: f"Download **{tag[1:]}** from", updated)
        if updated == text:
            return
        body = {
            "message": f"Update downloads for {tag}",
            "branch": "main", "sha": current["sha"],
            "content": base64.b64encode(updated.encode()).decode(),
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "readme.json"
            path.write_text(json.dumps(body))
            result = subprocess.run(["gh", "api", endpoint, "--method", "PUT", "--input", str(path)],
                                    capture_output=True, text=True)
        if result.returncode == 0:
            print("README download links updated on main.")
            return
        if "HTTP 409" not in result.stderr or attempt == 2:
            raise RuntimeError("Release is public, but README update failed: " + result.stderr)
    raise RuntimeError("README kept changing; update its links to the published release.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", "CipherAtlas/Hearthwillow"))
    parser.add_argument("--prepare-only", action="store_true", help="Render notes without contacting GitHub.")
    args = parser.parse_args()
    release_key(args.tag)
    if not re.fullmatch(r"[0-9a-f]{40}", args.commit):
        parser.error("--commit must be the full source commit SHA")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repository):
        parser.error("--repository must be OWNER/REPO")
    output = ROOT / "build/releases"
    output.mkdir(parents=True, exist_ok=True)
    notes = (ROOT / "docs/RELEASE-TEMPLATE.md").read_text()
    for name, value in {"TAG": args.tag, "VERSION": args.tag[1:],
                        "REPOSITORY": args.repository, "COMMIT": args.commit}.items():
        notes = notes.replace("{{" + name + "}}", value)
    if re.search(r"\{\{[A-Z]+\}\}", notes):
        raise RuntimeError("Unresolved release-note placeholder")
    note_path = output / "release-notes.md"
    note_path.write_text(notes)
    if args.prepare_only:
        print("Prepared", note_path)
        return

    reference = json.loads(gh("api", f"repos/{args.repository}/git/ref/tags/{args.tag}"))["object"]
    while reference["type"] == "tag":
        reference = json.loads(gh("api", f"repos/{args.repository}/git/tags/{reference['sha']}"))["object"]
    if reference["type"] != "commit" or reference["sha"] != args.commit:
        raise RuntimeError("Remote tag no longer points to the built source commit.")
    view = ["release", "view", args.tag, "--repo", args.repository,
            "--json", "isDraft,targetCommitish,assets,url,isPrerelease"]
    # The REST release-by-tag endpoint only finds published releases; gh also finds drafts.
    existing = subprocess.run(["gh", *view], capture_output=True, text=True)
    if existing.returncode == 0:
        release = json.loads(existing.stdout)
        if not release["isDraft"]:
            raise RuntimeError("This version is already published; use a new tag. Assets are immutable.")
        if release["targetCommitish"] != args.commit:
            raise RuntimeError("Existing draft targets a different source commit.")
    elif "release not found" not in existing.stderr and "HTTP 404" not in existing.stderr:
        raise RuntimeError("Cannot inspect the release: " + existing.stderr)
    else:
        gh("release", "create", args.tag, "--repo", args.repository, "--verify-tag",
           "--target", args.commit, "--draft", "--latest=false",
           "--title", f"Hearthwillow {args.tag[1:]}",
           "--notes-file", str(note_path), "--prerelease=" + str("-" in args.tag).lower())
    paths = [output / name for name in ASSETS]
    gh("release", "upload", args.tag, "--repo", args.repository, "--clobber", *(str(p) for p in paths))
    remote = json.loads(gh(*view))
    if not remote["isDraft"] or remote["targetCommitish"] != args.commit:
        raise RuntimeError("Draft state or source target changed during upload.")
    by_name = {asset["name"]: asset for asset in remote["assets"]}
    if set(by_name) != set(ASSETS):
        raise RuntimeError("Draft must contain exactly the three expected download assets.")
    for path in paths:
        asset = by_name[path.name]
        with path.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        if asset["size"] != path.stat().st_size:
            raise RuntimeError(f"Remote size differs: {path.name}")
        remote_digest = asset.get("digest")
        if remote_digest is None:
            with tempfile.TemporaryDirectory() as directory:
                gh("release", "download", args.tag, "--repo", args.repository,
                   "--pattern", path.name, "--dir", directory)
                with (Path(directory) / path.name).open("rb") as stream:
                    remote_digest = "sha256:" + hashlib.file_digest(stream, "sha256").hexdigest()
        if remote_digest != "sha256:" + digest:
            raise RuntimeError(f"Remote checksum differs: {path.name}")
    gh("release", "edit", args.tag, "--repo", args.repository, "--draft=false",
       "--prerelease=" + str("-" in args.tag).lower(), "--latest=false",
       "--notes-file", str(note_path))
    published = json.loads(gh(*view))
    if published["isDraft"] or published["isPrerelease"] != ("-" in args.tag):
        raise RuntimeError("Release publication state differs from the requested tag.")
    for name in ASSETS[:2]:
        subprocess.run(["curl", "-f", "-sS", "-I", "-L", "--retry", "3", "--max-time", "60",
                        "-o", os.devnull, f"https://github.com/{args.repository}/releases/download/{args.tag}/{name}"],
                       check=True)
    refresh_readme(args.repository, args.tag)
    print("Published", published["url"])


if __name__ == "__main__":
    main()

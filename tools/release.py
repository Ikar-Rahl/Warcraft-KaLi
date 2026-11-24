"""Publishing an addon from a tag (Ikar 2026-11-24: "One tag per addon. Automated publishing."). A tag <addon>-<version>
pushed to GitHub (quest-0.9.1, recipe-0.9.1, hud-0.9.1) runs .github/workflows/release.yml, which runs this:

1. the tag held against the addon: its TOC's ## Version, a « ## <version> » section in its CHANGELOG.md;
2. the package checked (the offline runner's check, which needs only the addon's own files);
3. the zip built: the addon's folder alone, a folder entry for every folder (CurseForge refused one without them);
4. the GitHub release made, the zip attached, the version's changelog as its notes (Ikar: "Yes, release with a zip");
5. the zip uploaded to CurseForge with the same changelog, in Markdown, last: a failed run can be run again.

The description and the pictures stay by hand, as CurseForge has no API for them (Ikar: "desc and image by hands"):
the run's summary says when the addon's README or docs/images changed since its previous tag. The offline tests need
the local reference copies, so they are run here before the tag, not on GitHub.

    python -I tools/release.py quest-0.9.1 --dry-run   all but the uploads, from the working tree, no tag needed:
                                                       the zip in a folder of its own, the changelog and the summary
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
import uuid
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kali.paths import ROOT  # noqa: E402
from kali.shared import ADDONS  # noqa: E402

TITLES = {"quest": "KaLi Quest", "recipe": "KaLi Recipe", "hud": "KaLi HUD"}
SLUGS = {"quest": "kali-quest", "recipe": "kali-recipe", "hud": "kali-hud"}
# Each addon's files' type on CurseForge, and its GitHub release a pre-release unless "release". Releases since 0.9.1
# (Ikar 2026-11-24: "Still beta, but the file release shoudl not be beta anymore. So that it is more visible to
# everyone": the CurseForge app shows a project only once it has a Release file, and offers betas only to players who
# ask for them). The addons stay betas in their own words, the README's notice.
RELEASE_TYPE = {"quest": "release", "recipe": "release", "hud": "release"}

CURSEFORGE = "https://wow.curseforge.com"
# CurseForge's game version type for World of Warcraft Forever, as BigWigs' packager has it (release.sh, 2026-11-04).
FOREVER = 88568
USER_AGENT = "kali-release"
RELEASES = ROOT.parent / "release"


def fail(message):
    raise SystemExit(f"release: {message}")


def run(*args, check=True):
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
    if check and result.returncode:
        fail(f"{' '.join(args)}\n{result.stdout}{result.stderr}")
    return result


def parse_tag(tag):
    found = re.fullmatch(r"(quest|recipe|hud)-(\d+\.\d+\.\d+)", tag)
    if not found:
        fail(f"{tag!r} is not <addon>-<version>, as quest-0.9.1 (addons: {', '.join(ADDONS)})")
    return found.group(1), found.group(2)


def toc_fields(folder, addon):
    text = (folder / f"{addon}.toc").read_text(encoding="utf-8")
    return dict(re.findall(r"^## ([\w-]+):[ \t]*(.*?)\s*$", text, re.M))


def changelog(folder, version):
    """The version's section of CHANGELOG.md, from the line under its heading to the next version's."""
    text = (folder / "CHANGELOG.md").read_text(encoding="utf-8")
    found = re.search(rf"^## {re.escape(version)}\b.*?$(.*?)(?=^## |\Z)", text, re.M | re.S)
    if not found or not found.group(1).strip():
        fail(f"{folder.name}/CHANGELOG.md has no « ## {version} » section")
    return found.group(1).strip() + "\n"


def game_versions(fields):
    """The TOC's interface numbers as the game's versions: 16001 is 1.60.1."""
    names = []
    for number in re.findall(r"\d+", fields.get("Interface", "")):
        names.append(f"{int(number[:-4])}.{int(number[-4:-2])}.{int(number[-2:])}")
    if not names:
        fail("the TOC has no ## Interface")
    return names


def package_problems(addons_dir, addon):
    from kali import checks  # needs lupa in tools/pylib, as the offline runner
    checks.configure(ADDONS=addons_dir)
    problems, count = checks.package_problems(addon)
    if problems:
        fail("the package:\n  " + "\n  ".join(problems))
    return count


def build_zip(folder, target):
    """The addon's folder alone, as `zip -r` writes it: each folder's entry, then its files, then its folders."""
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for here, dirs, files in os.walk(folder):
            dirs.sort()
            base = Path(here)
            inside = base.relative_to(folder.parent).as_posix()
            z.write(base, inside + "/")
            for name in sorted(files):
                z.write(base / name, f"{inside}/{name}")
    return target


def compare_zip(built, published):
    """For a dry run: the files of the zip built against a zip already made, the line endings left aside."""
    with zipfile.ZipFile(built) as a, zipfile.ZipFile(published) as b:
        files_a = {n for n in a.namelist() if not n.endswith("/")}
        files_b = {n for n in b.namelist() if not n.endswith("/")}
        differ = sorted(n for n in files_a & files_b
                        if a.read(n).replace(b"\r\n", b"\n") != b.read(n).replace(b"\r\n", b"\n"))
        return sorted(files_a - files_b), sorted(files_b - files_a), differ


def previous_tag(key, version):
    def as_numbers(v):
        return tuple(int(n) for n in v.split("."))
    tags = run("git", "tag", "--list", f"{key}-*").stdout.split()
    older = [t for t in tags if re.fullmatch(rf"{key}-\d+\.\d+\.\d+", t)
             and as_numbers(t.split("-", 1)[1]) < as_numbers(version)]
    return max(older, key=lambda t: as_numbers(t.split("-", 1)[1]), default=None)


def by_hand(key, addon, version):
    """What stays to do on CurseForge's site: the description when the README changed, the Gallery's pictures."""
    before = previous_tag(key, version)
    readme = f"{key}/addon/{addon}/README.md"
    images = f"{key}/docs/images"
    if not before:
        return [f"No earlier tag of {TITLES[key]} to compare with: look at the description and the Gallery yourself."]
    lines = []
    if run("git", "diff", "--quiet", before, "--", readme, check=False).returncode:
        lines.append(f"The description changed since {before}: paste `{readme}` in the description's Markdown mode.")
    changed = run("git", "diff", "--name-status", before, "--", images).stdout.split("\n")
    changed = [line.replace("\t", " ") for line in changed if line.strip()]
    if changed:
        lines.append(f"Pictures changed since {before} (the description's follow GitHub; the Gallery's are uploaded "
                     "by hand): " + ", ".join(f"`{line}`" for line in changed))
    return lines or [f"Neither the description nor the pictures changed since {before}."]


def request(method, url, token, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method,
                                 headers={"X-Api-Token": token, "User-Agent": USER_AGENT, **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=300) as response:
            return json.loads(response.read() or b"null")
    except urllib.error.HTTPError as e:
        fail(f"CurseForge answered {e.code} to {method} {url}: {e.read().decode('utf-8', 'replace')[:2000]}")


def curseforge_version_ids(token, names):
    versions = request("GET", f"{CURSEFORGE}/api/game/wow/versions", token)
    forever = {v["name"]: v["id"] for v in versions if v.get("gameVersionTypeID") == FOREVER}
    missing = [n for n in names if n not in forever]
    if missing:
        # Where the same names are, should Forever's type have another number than FOREVER's.
        elsewhere = sorted({v.get("gameVersionTypeID") for v in versions if v.get("name") in missing})
        fail(f"CurseForge has no Forever version {', '.join(missing)} (it has: {', '.join(sorted(forever)) or 'none'}; "
             f"the same names under the version types {elsewhere or 'none'})")
    return [forever[n] for n in names]


def upload_curseforge(token, project, metadata, archive):
    boundary = uuid.uuid4().hex
    parts = [
        f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n\r\n'.encode(),
        json.dumps(metadata).encode("utf-8"),
        f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{archive.name}"\r\n'
        "Content-Type: application/zip\r\n\r\n".encode(),
        archive.read_bytes(),
        f"\r\n--{boundary}--\r\n".encode(),
    ]
    return request("POST", f"{CURSEFORGE}/api/projects/{project}/upload-file", token, b"".join(parts),
                   {"Content-Type": f"multipart/form-data; boundary={boundary}"})


def github_release(tag, title, notes, archive, beta):
    notes_file = archive.with_name("notes.md")
    notes_file.write_text(notes, encoding="utf-8")
    if run("gh", "release", "view", tag, check=False).returncode == 0:
        run("gh", "release", "upload", tag, str(archive), "--clobber")
        run("gh", "release", "edit", tag, "--title", title, "--notes-file", str(notes_file))
    else:
        run("gh", "release", "create", tag, str(archive), "--verify-tag", "--title", title,
            "--notes-file", str(notes_file), *(["--prerelease"] if beta else []))
    return run("gh", "release", "view", tag, "--json", "url", "--jq", ".url").stdout.strip()


def summary(lines):
    text = "\n".join(lines) + "\n"
    print(text)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as f:
            f.write(text)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry-run" in sys.argv
    if len(args) != 1:
        fail(__doc__)
    tag = args[0]
    key, version = parse_tag(tag)
    addons_dir, addon = ADDONS[key]
    folder = addons_dir / addon
    fields = toc_fields(folder, addon)
    if fields.get("Version") != version:
        fail(f"{addon}.toc says ## Version: {fields.get('Version')}, the tag {version}")
    project = fields.get("X-Curse-Project-ID")
    if not project:
        fail(f"{addon}.toc has no ## X-Curse-Project-ID")
    notes = changelog(folder, version)
    names = game_versions(fields)
    count = package_problems(addons_dir, addon)

    out = Path(tempfile.mkdtemp(prefix=f"{addon}-{version}-"))
    archive = build_zip(folder, out / f"{addon}-{version}.zip")
    title = f"{TITLES[key]} {version}"
    kind = RELEASE_TYPE[key]
    lines = [f"## {title}", "", f"- {count} files, `{archive.name}`, {kind}, Forever {', '.join(names)}"]

    if dry:
        lines.append(f"- Dry run: nothing uploaded. The zip: `{archive}`")
        published = RELEASES / f"{addon}-{version}" / archive.name
        if published.exists():
            added, gone, differ = compare_zip(archive, published)
            same = not (added or gone or differ)
            lines.append(f"- Against `{published}`: " + ("the same files." if same else
                         f"new {added}, gone {gone}, different {differ}"))
        # The token tried too, uploading nothing (Ikar 2026-11-24: "Yes"): CurseForge's game versions read with it,
        # Forever's found in them, as a tag's run needs.
        token = os.environ.get("CF_API_TOKEN")
        if token:
            ids = curseforge_version_ids(token, names)
            lines.append(f"- CurseForge: the token works; Forever {', '.join(names)} is its game version "
                         f"{', '.join(map(str, ids))}")
        else:
            lines.append("- CurseForge: no CF_API_TOKEN here, so the token and the game version weren't tried")
    else:
        token = os.environ.get("CF_API_TOKEN")
        if not token:
            fail("no CF_API_TOKEN: the repository's secret, a token made on authors.curseforge.com")
        ids = curseforge_version_ids(token, names)
        url = github_release(tag, title, notes, archive, kind != "release")
        lines.append(f"- GitHub: {url}")
        result = upload_curseforge(token, project, {
            "displayName": title, "gameVersions": ids, "releaseType": kind,
            "changelog": notes, "changelogType": "markdown"}, archive)
        lines.append(f"- CurseForge: file {result.get('id') if isinstance(result, dict) else result} on "
                     f"https://www.curseforge.com/wow/addons/{SLUGS[key]}/files")
    lines += ["", "### By hand on CurseForge", ""] + [f"- {line}" for line in by_hand(key, addon, version)]
    lines += ["", "### Changelog sent", "", notes]
    summary(lines)


if __name__ == "__main__":
    main()

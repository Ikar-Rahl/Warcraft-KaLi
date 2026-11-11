"""Screenshot the bench in headless Edge, one PNG per state, to check it without opening a browser.

Usage: python -I recipe/tools/shot.py <out_dir> [--page <html>] [--size WxH] <name>=<hash> [<name>=<hash> ...]
Example: shot.py out merchant="scene=merchant&reset=1&hover=.mitem:nth-child(5)"
"""
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from kali.paths import EDGE  # noqa: E402
PAGE = (Path(__file__).resolve().parents[1] / "bench/index.html").as_uri()

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
args, size = sys.argv[2:], "1920,1080"
if args[:1] == ["--page"]:
    PAGE, args = Path(args[1]).resolve().as_uri(), args[2:]
if args[:1] == ["--size"]:
    size, args = args[1].replace("x", ","), args[2:]
with tempfile.TemporaryDirectory() as profile:
    for arg in args:
        name, _, frag = arg.partition("=")
        png = out / f"{name}.png"
        subprocess.run([str(EDGE), "--headless=new", "--disable-gpu", f"--user-data-dir={profile}", "--hide-scrollbars",
                        f"--window-size={size}", "--virtual-time-budget=4000", "--allow-file-access-from-files",
                        f"--screenshot={png}", f"{PAGE}#{frag}"], check=False, capture_output=True, timeout=120)
        print(name, "ok" if png.exists() else "missing")

"""Screenshot the borders bench in headless Edge, one PNG per state, to check it without opening a browser.

Usage: python -I hud/tools/shot.py <out_dir> [--size WxH] <name>=<hash> [<name>=<hash> ...]
Example: shot.py out bronze="look=bronze&zoom=3" iron="look=fer&p.width=6"
"""
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from kali.paths import EDGE  # noqa: E402
PAGE = (Path(__file__).resolve().parents[1] / "bench/borders.html").as_uri()

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
args, size = sys.argv[2:], "1800,2400"
if args[:1] == ["--size"]:
    size, args = args[1].replace("x", ","), args[2:]
with tempfile.TemporaryDirectory() as profile:
    for arg in args:
        name, _, frag = arg.partition("=")
        png = out / f"{name}.png"
        png.unlink(missing_ok=True)
        subprocess.run([str(EDGE), "--headless=new", "--disable-gpu", f"--user-data-dir={profile}", "--hide-scrollbars",
                        f"--window-size={size}", "--virtual-time-budget=8000", "--allow-file-access-from-files",
                        f"--screenshot={png}", f"{PAGE}#{frag}"], check=False, capture_output=True, timeout=180)
        print(name, "ok" if png.exists() else "missing")

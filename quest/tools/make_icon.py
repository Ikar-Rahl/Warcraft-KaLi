"""Make one of the candidates on quest/bench/icons.html the addon's icon: a 64 by 64 TGA in quest/addon/KaLiQuest/Media.

Headless Edge draws the candidate and hands back its pixels; tools/kali/icon.py writes them as an uncompressed 32-bit
TGA, the format most Forever addons ship their icons in. The TOC names it in ## IconTexture.

Run with: python -I quest/tools/make_icon.py <id>     (the ids are on the page, under each name)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from kali.icon import install  # noqa: E402
from kali.paths import QUEST  # noqa: E402

if __name__ == "__main__":
    install(sys.argv, page=QUEST / "bench/icons.html", out=QUEST / "addon/KaLiQuest/Media/Icon.tga",
            # Tells icons.html which candidate the addon holds.
            installed_js=QUEST / "bench/js/icon-installed.js", variable="KQ_ICON_INSTALLED",
            tool="quest/tools/make_icon.py", usage=__doc__)

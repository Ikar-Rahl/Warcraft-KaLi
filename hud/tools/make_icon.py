"""Make one of the candidates on hud/bench/icons.html the addon's icon: a 64 by 64 TGA in hud/addon/KaLiHUD/Media, as
quest/tools/make_icon.py does for KaLi Quest.

The TOC names it in ## IconTexture (the AddOns list and the addon compartment). The page draws its K in the game's
font, from the bench's art/ (hud/bench/art/FRIZQT__.TTF). make_media.py no longer writes this file.

Run with: python -I hud/tools/make_icon.py <id>     (the ids are on the page, under each name)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from kali.icon import install  # noqa: E402
from kali.paths import HUD  # noqa: E402

if __name__ == "__main__":
    install(sys.argv, page=HUD / "bench/icons.html", out=HUD / "addon/KaLiHUD/Media/Icon.tga",
            # Tells icons.html which candidate the addon holds.
            installed_js=HUD / "bench/js/icon-installed.js", variable="KH_ICON_INSTALLED",
            tool="hud/tools/make_icon.py", usage=__doc__)

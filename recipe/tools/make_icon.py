"""Make one of the candidates on recipe/bench/icons.html the addon's icon: a 64 by 64 TGA in
recipe/addon/KaLiRecipe/Media, as quest/tools/make_icon.py does for KaLi Quest.

The TOC names it in ## IconTexture, and UI/MinimapButton.lua gives the same file to the minimap button and the bars'
launcher. The page draws its K in the game's font, from the bench's art/ (python -I recipe/tools/bench_data.py).

Run with: python -I recipe/tools/make_icon.py <id>     (the ids are on the page, under each name)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from kali.icon import install  # noqa: E402
from kali.paths import RECIPE  # noqa: E402

if __name__ == "__main__":
    install(sys.argv, page=RECIPE / "bench/icons.html", out=RECIPE / "addon/KaLiRecipe/Media/Icon.tga",
            # Tells icons.html which candidate the addon holds.
            installed_js=RECIPE / "bench/js/icon-installed.js", variable="KR_ICON_INSTALLED",
            tool="recipe/tools/make_icon.py", usage=__doc__)

"""The talents' values KaLi HUD takes from Forever's data (Data/Effects.lua's TALENT_POINTS, a value by rank) against the
game's own talent tooltips at each rank, as the probe read them in game (/khprobe talents, then /reload: the account's
KaLiHUD_Probe.lua). Ikar 2026-11-21: "review all talent, all similar assumption, can't you test them ?".

For each talent of the class the probe saw: its ranks as the game gives them (active, purchased, increased, most), and
for each rank whether each value the HUD has for it is a figure the game's tooltip states at that rank; the talent's
aura points where the game shows it as an aura. Writes nothing.
Run with: python -I hud/tools/check_talents.py [path to KaLiHUD_Probe.lua]
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from kali.paths import use_pylib  # noqa: E402

use_pylib()
sys.stdout.reconfigure(encoding="utf-8")
from lupa.lua51 import LuaRuntime  # noqa: E402

DEFAULT = Path(r"c:\devel\World of Warcraft\_forever_\WTF\Account")


def saved_file():
    if len(sys.argv) > 1:
        return Path(sys.argv[1])
    found = sorted(DEFAULT.glob("*/SavedVariables/KaLiHUD_Probe.lua"), key=lambda p: p.stat().st_mtime)
    if not found:
        sys.exit("no KaLiHUD_Probe.lua: run /khprobe talents in game, then /reload")
    return found[-1]


def figures(text):
    """The numbers a tooltip states, as numbers (French decimals with a comma)."""
    return {float(n.replace(",", ".")) for n in re.findall(r"\d+(?:[.,]\d+)?", text or "")}


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(saved_file().read_text(encoding="utf-8"))
    db = lua.globals().KaLiHUDProbeDB
    talents = db and db.talents
    if not talents:
        sys.exit("the probe has no talents: run /khprobe talents in game, then /reload")
    print(f"{talents['class']} level {talents.level}")
    wrong = 0
    for i in range(1, len(talents) + 1):
        t = talents[i]
        if t is None:
            continue
        ranks = {}
        for part in (t.points or "").split(";"):
            if part:
                index, _, values = part.split(":", 2)
                for r, v in enumerate(values.split(","), 1):
                    ranks.setdefault(r, []).append((int(index), abs(float(v))))
        head = (f"{t.spell} {t.name}: rank {t.activeRank} (purchased {t.ranksPurchased}, increased "
                f"{t.ranksIncreased}, most {t.maxRanks})" + (f", aura {t.aura}" if t.aura else ""))
        lines = []
        for r in sorted(ranks):
            said = figures(t.ranks[r] if t.ranks else "")
            missing = [f"effect {index} {v:g}" for index, v in ranks[r] if v not in said]
            if missing:
                lines.append(f"  rank {r}: the HUD's {', '.join(missing)} not in the game's tooltip: "
                             f"{(t.ranks[r] or '')[:220]}")
        if lines or not ranks:
            wrong += bool(lines)
            print(head + ("" if ranks else "  (no values by rank: the spell's own)"))
            for line in lines:
                print(line)
    print(f"\n{wrong} talent(s) whose HUD values aren't the game's tooltip's")


if __name__ == "__main__":
    main()

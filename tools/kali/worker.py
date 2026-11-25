"""An addon's runner kept running for tools/breaks.py: loaded once, it runs its parts again and again on a copy of the
addon's folders, where tools/breaks.py plants one break after another. A break then pays neither Python's start nor
the reading of the game's files a second time (Blizzard's source, the API docs, the build's tables: the @cache
functions of tools/kali/checks.py and the runners keep what they read).

Started as: python -I tools/kali/worker.py <runner> <copy of the addon's folders>
It reads one request a line, a JSON list: the runner's arguments (["--only", "smoke", "--at", "..."]). It answers each
with one line on its output, KALI-WORKER {"code": <the runner's exit code>, "output": "<all the runner printed>"},
and nothing else there: what the game's Lua prints goes to its error output. A runner that raises answers as the
command would, with its traceback and code 1. tools/breaks.py stops a worker that takes too long, and starts another.
"""
import contextlib
import gc
import io
import json
import os
import runpy
import sys
import traceback
from pathlib import Path

MARK = "KALI-WORKER "


def main():
    runner, copy = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
    # The answers on a handle of their own; whatever else writes to the output (the game's Lua, straight to the C
    # library's) lands in the error output.
    answers = os.fdopen(os.dup(1), "w", encoding="ascii", newline="\n")
    os.dup2(2, 1)
    sys.stdin.reconfigure(encoding="utf-8")
    # The runner reads --addons once, as it loads (checks.configure).
    sys.argv = [str(runner), "--addons", str(copy)]
    names = runpy.run_path(str(runner), run_name="kali_runner")
    for line in sys.stdin:
        if not line.strip():
            continue
        sys.argv = [str(runner), "--addons", str(copy), *json.loads(line)]
        out = io.StringIO()
        code = 0
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            try:
                names["main"]()
            except SystemExit as done:
                code = done.code if isinstance(done.code, int) else (0 if done.code is None else 1)
            except BaseException:  # the runner's own failure, as the command would show it
                traceback.print_exc()
                code = 1
        gc.collect()
        answers.write(MARK + json.dumps({"code": code, "output": out.getvalue()}) + "\n")
        answers.flush()


if __name__ == "__main__":
    main()

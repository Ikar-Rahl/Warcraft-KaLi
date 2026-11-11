"""Copy the shared code (shared/) into each addon, after editing it.

Run with: python -I tools/sync_shared.py          writes the copies that differ
          python -I tools/sync_shared.py --check  writes nothing, lists what differs (tools/run_tests.py does this)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kali import shared  # noqa: E402

if "--check" in sys.argv:
    found = shared.problems()
    print("\n".join(found) if found else "shared: every copy matches its source")
    sys.exit(1 if found else 0)
print(f"shared: {shared.sync()} copies written")
found = shared.problems()
if found:
    print("\n".join(found))
    sys.exit(1)

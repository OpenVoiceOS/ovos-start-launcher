"""Build the self-contained v2 launcher from audited shell and message sources."""
from __future__ import annotations

import json
from pathlib import Path
import shlex

ROOT = Path(__file__).resolve().parents[1]


def build() -> str:
    """Validate message parity and embed localized runtime without network imports."""
    catalogs = json.loads((ROOT / "locales/messages.json").read_text())
    keys = set(catalogs["en-us"])
    blocks = ["message() {", "  case \"${ovos_locale:-en-us}:$1\" in"]
    for locale, catalog in catalogs.items():
        if set(catalog) != keys or any(not isinstance(value, str) or not value for value in catalog.values()):
            raise ValueError(f"Incomplete messages for {locale}")
        for key, value in catalog.items():
            blocks.append(f"    {locale}:{key}) printf '%s' {shlex.quote(value)};;")
    blocks.extend(["    *) printf '%s' 'OVOS: unknown message';;", "  esac", "}", "say() { message \"$1\"; printf '\\n'; }"])
    messages = "\n".join(blocks) + "\n"
    # Serialize only the chosen trusted catalog for the private checker. Keeping
    # all twelve catalogs twice exceeds Linux's per-argument sh -c limit.
    messages += '''# Emit literal shell definitions; expansion occurs only in the resulting checker.
# shellcheck disable=SC2016
write_messages() {
  printf '%s\\n' 'message() {' '  case "$1" in'
  for ovos_key in @KEYS@; do
    printf '%s' "    $ovos_key) printf '%s' '"
    message "$ovos_key" | sed "s/'/'\\\\\\\\''/g"
    printf '%s\\n' "';;"
  done
  printf '%s\\n' "    *) printf '%s' 'OVOS: unknown message';;" '  esac' '}'
  printf '%s\\n' 'say() { message "$1"; printf "\\n"; }'
}
'''.replace("@KEYS@", " ".join(sorted(keys)))
    callbacks = (ROOT / "lib/callback.sh").read_text()
    runtime = callbacks + "\n" + (ROOT / "lib/runtime.sh").read_text()
    launcher = (ROOT / "lib/launcher.sh.in").read_text()
    return (launcher.replace("# @MESSAGES@", messages)
            .replace("# @CALLBACKS@", callbacks).replace("# @RUNTIME@", runtime)
            .replace("# @ANSIBLE_PROGRESS@", (ROOT / "lib/ansible_progress.py").read_text())
            .replace("# @SCENARIO_CLEANUP@", (ROOT / "lib/scenario_cleanup.py").read_text()))


if __name__ == "__main__":
    (ROOT / "v2.sh").write_text(build())

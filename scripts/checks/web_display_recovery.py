#!/usr/bin/env python3
"""Web display recovery gate (app-switch freeze, 2026-10-08).

web/shell.html catches a lost WebGL context, covers the canvas, reloads the page
and leaves a sessionStorage flag; scripts/ui/main_menu.gd reads that flag and
resumes the run by itself. The two files cannot share a constant, so this gate
checks the copies and the parts of the shell a browser test would otherwise be
the only thing to notice:

  * the flag's key is the same string in both files
  * the shell listens for `webglcontextlost` on the canvas in the capture phase,
    stops the event (so the engine's alert() never runs), and registers that
    listener BEFORE engine.startGame (the engine adds its own while starting)
  * the overlay has its title, line and RELOAD button, and the alternate line
  * the overlay copy has no em or en dash and no line over 40 characters
  * the game is marked started only once startGame resolves (the context
    re-check must never run getContext on a canvas the engine has not set up)

Then it proves it can fail: each rule is broken in memory and must be reported.
The behaviour itself (overlay, no alert, reload, resume) is exercised in a real
browser by scripts/debug/web_display_loss_test.cjs, which needs a Web export and
so runs beside web_loader_test.cjs, outside verify_gate.py. The game's half is
gated headless by the `resume guard` gate (legs auto, auto_blocked).

Exit 0 = pass, 1 = drift.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHELL = ROOT / "web" / "shell.html"
MENU = ROOT / "scripts" / "ui" / "main_menu.gd"
MAX_COPY_CHARS = 40


def check(shell: str, menu: str) -> list[str]:
    failures: list[str] = []
    shell_key = re.search(r"const OP_RESUME_KEY = '([^']+)'", shell)
    menu_key = re.search(r'const DISPLAY_RELOAD_FLAG := "([^"]+)"', menu)
    if shell_key is None:
        failures.append("shell.html does not define OP_RESUME_KEY")
    if menu_key is None:
        failures.append("main_menu.gd does not define DISPLAY_RELOAD_FLAG")
    if shell_key and menu_key and shell_key.group(1) != menu_key.group(1):
        failures.append(f"flag key differs: shell '{shell_key.group(1)}' vs menu '{menu_key.group(1)}'")
    if "sessionStorage.removeItem(k)" not in menu:
        failures.append("main_menu.gd does not clear the flag when it reads it")

    listener = re.search(
        r"canvas\.addEventListener\('webglcontextlost',\s*function \(ev\) \{(.*?)\},\s*true\);", shell, re.S)
    if listener is None:
        failures.append("shell.html has no capture-phase webglcontextlost listener on the canvas")
    else:
        if "stopImmediatePropagation()" not in listener.group(1):
            failures.append("the webglcontextlost listener does not stop the event (the engine's alert would run)")
        start = shell.find("engine.startGame(")
        if start == -1 or listener.start() > start:
            failures.append("the webglcontextlost listener is not registered before engine.startGame")

    started = shell.find("window.__opGameStarted = true")
    then = shell.find("}).then(function () {")
    if started == -1 or then == -1 or started < then:
        failures.append("the game is not marked started inside startGame's then()")

    copy: dict[str, str] = {}
    for element, tag in (("op-lost-title", "div"), ("op-lost-line", "div"), ("op-lost-reload", "button")):
        found = re.search(rf'<{tag} id="{element}"[^>]*>([^<]*)</{tag}>', shell)
        if found is None or not found.group(1).strip():
            failures.append(f"shell.html overlay is missing #{element} or its text")
        else:
            copy[element] = found.group(1).strip()
    manual = re.search(r"line\.textContent = '([^']+)'", shell)
    if manual is None:
        failures.append("shell.html has no alternate line for the RELOAD button state")
    else:
        copy["manual line"] = manual.group(1)
    for where, text in copy.items():
        if "—" in text or "–" in text:
            failures.append(f"overlay copy has a dash in {where}: {text!r}")
        if len(text) > MAX_COPY_CHARS:
            failures.append(f"overlay copy in {where} is over {MAX_COPY_CHARS} characters: {text!r}")
    return failures


def main() -> int:
    shell = SHELL.read_text(encoding="utf-8")
    menu = MENU.read_text(encoding="utf-8")
    failures = check(shell, menu)
    for failure in failures:
        print(f"   FAIL {failure}")

    # Deliberate breaks, in memory: each must be reported.
    breaks = {
        "flag key drift": (shell.replace("const OP_RESUME_KEY = 'op_resume_after_reload'", "const OP_RESUME_KEY = 'op_resume'"), menu),
        "flag never cleared": (shell, menu.replace("sessionStorage.removeItem(k);", "")),
        "event not stopped": (shell.replace("ev.stopImmediatePropagation();", ""), menu),
        "listener not in capture phase": (shell.replace("displayLost();\n\t}, true);", "displayLost();\n\t});"), menu),
        "dash in the copy": (shell.replace("Reloading to bring it back.", "Reloading — one moment."), menu),
        "overlay button removed": (re.sub(r'<button id="op-lost-reload"[^>]*>[^<]*</button>', "", shell), menu),
    }
    for name, (broken_shell, broken_menu) in breaks.items():
        if (broken_shell, broken_menu) == (shell, menu):
            print(f"   FAIL deliberate break '{name}' changed nothing - the break is stale")
            failures.append(name)
        elif not check(broken_shell, broken_menu):
            print(f"   FAIL deliberate break '{name}' was not detected")
            failures.append(name)
    if failures:
        print(f"[WEB_DISPLAY_RECOVERY] FAIL - {len(failures)} problem(s)")
        return 1
    print(f"[WEB_DISPLAY_RECOVERY] PASS (flag key, listener order, overlay copy; {len(breaks)} deliberate breaks detected)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

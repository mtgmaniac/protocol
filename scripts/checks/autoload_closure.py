#!/usr/bin/env python3
"""No bare autoload identifiers where a headless `-s` test compiles them.

`godot -s entry.gd` compiles the entry script BEFORE autoloads register, so a
bare autoload identifier (`AudioManager`, `GameState`, ...) anywhere in the
entry's COMPILE-TIME closure is "Identifier not found" — the error cascades up
the chain and the test idles until its timeout (TRUTH.md, Verify commands).
Four incidents before this gate; the fourth was training_prompt.gd via
training_flow (2026-09-25). Resolve autoloads through get_node("/root/...").

Compile-time edges: preload("res://x.gd"), extends "res://x.gd", extends
ClassName, and a class_name used in code — unless the file shadows that name
with a runtime `load()` local (the effect_pip_overflow_test pattern). Runtime
load()/change_scene are NOT edges: those compile after autoloads exist, which
is why battle_scene.gd's bare references are safe while no -s test reaches it.

Every run first re-injects the known incidents into an in-memory overlay and
FAILS if any goes undetected — a guard that cannot see its own precedents is a
hollow gate.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

STRING = re.compile(r'"""[\s\S]*?"""|"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'')


def code_only(src):
    """Blank out strings, then comments, so paths like "/root/GameState" never count."""
    return re.sub(r"#[^\n]*", "", STRING.sub('""', src))


def autoload_names(project_text):
    names, in_section = [], False
    for line in project_text.splitlines():
        if line.startswith("["):
            in_section = line.strip() == "[autoload]"
            continue
        if in_section and "=" in line:
            names.append(line.split("=", 1)[0].strip())
    return names


def entry_scripts(gate_text):
    return sorted(set(re.findall(r'"-s",\s*"(scripts/[^"]+\.gd)"', gate_text)))


class Project:
    def __init__(self, files, autoloads):
        self.files = files  # res-relative path -> source
        self.autoloads = autoloads
        self.class_of = {}
        for path, src in files.items():
            m = re.search(r"^class_name\s+(\w+)", src, re.M)
            if m:
                self.class_of[m.group(1)] = path
        self.bare = re.compile(r"(?<![\w.$])(?:%s)\b" % "|".join(map(re.escape, autoloads)))

    def edges(self, path):
        src = self.files[path]
        code = code_only(src)
        out = set(re.findall(r'preload\(\s*"res://([^"]+\.gd)"\s*\)', src))
        out.update(re.findall(r'^extends\s+"res://([^"]+\.gd)"', src, re.M))
        shadowed = set(re.findall(r"\b(?:var|const)\s+(\w+)\s*(?::[^=\n]*)?=\s*load\(", code))
        for name, dep in self.class_of.items():
            if dep != path and name not in shadowed and re.search(r"(?<![\w.])%s\b" % name, code):
                out.add(dep)
        return {d for d in out if d in self.files}

    def closure(self, entry):
        seen, stack = set(), [entry]
        while stack:
            cur = stack.pop()
            if cur in seen or cur not in self.files:
                continue
            seen.add(cur)
            stack.extend(self.edges(cur) - seen)
        return seen

    def violations(self, entries):
        found = {}
        for entry in entries:
            for path in self.closure(entry):
                names = sorted(set(self.bare.findall(code_only(self.files[path]))))
                if names:
                    found.setdefault(path, (names, set()))[1].add(entry)
        return found


def load_project(root):
    files = {p.relative_to(root).as_posix(): p.read_text(encoding="utf-8", errors="replace")
             for p in root.glob("scripts/**/*.gd")}
    autoloads = autoload_names((root / "project.godot").read_text(encoding="utf-8"))
    entries = entry_scripts((root / "scripts/verify_gate.py").read_text(encoding="utf-8"))
    return files, autoloads, entries


# Known incidents, re-injected into an in-memory copy. Each must be flagged in
# the named file. (label, extra -s entries, {path: (find, replace)}, expected path)
INCIDENTS = [
    ("training_prompt.gd reached via preload chain (2026-09-25)", [],
     {"scripts/ui/training_prompt.gd": ('prompt.get_node("/root/AudioManager").play_select()', "AudioManager.play_select()")},
     "scripts/ui/training_prompt.gd"),
    ("EffectPip referenced by class_name from an -s test (2026-09-02)", [],
     {"scripts/debug/effect_pip_overflow_test.gd": ('var EffectPip: GDScript = load("res://scripts/ui/effect_pip.gd")', "")},
     "scripts/ui/effect_pip.gd"),
    ("operation lore test invoked with -s instead of its .tscn runner", ["scripts/debug/operation_lore_presentation_test.gd"],
     {}, None),
    # training_flow_test.gd is not an entry; tutorial_smoke_test reaches it ONLY
    # through `extends "res://..."`, so this is the extends-edge probe.
    ("bare autoload in an extends-only parent", [],
     {"scripts/debug/training_flow_test.gd": ("var errors: Array[String] = []", "var errors: Array[String] = []\nvar _probe = GameState")},
     "scripts/debug/training_flow_test.gd"),
]


def self_test(files, autoloads, entries):
    problems = []
    for label, extra_entries, patches, expected in INCIDENTS:
        overlay = dict(files)
        for path, (find, replace) in patches.items():
            if path not in overlay or find not in overlay[path]:
                problems.append(f"self-test '{label}': anchor missing in {path} — update the injection")
                break
            overlay[path] = overlay[path].replace(find, replace, 1)
        else:
            found = Project(overlay, autoloads).violations(entries + extra_entries)
            if expected is None:
                ok = any(extra in entries_hit for extra in extra_entries for _, entries_hit in found.values())
            else:
                ok = expected in found
            if not ok:
                problems.append(f"self-test '{label}': injected incident NOT detected")
    return problems


def main():
    files, autoloads, entries = load_project(ROOT)
    failures = self_test(files, autoloads, entries)
    for path, (names, hit_by) in sorted(Project(files, autoloads).violations(entries).items()):
        failures.append(f"{path}: bare autoload {', '.join(names)} in the compile-time closure of "
                        f"{', '.join(sorted(hit_by))} — use get_node(\"/root/...\")")
    print(f"-s entries: {len(entries)} | autoloads: {len(autoloads)} | self-test incidents: {len(INCIDENTS)}")
    for failure in failures:
        print(failure)
    print("[AUTOLOAD_CLOSURE] " + ("FAIL" if failures else "PASS"))
    return bool(failures)


if __name__ == "__main__":
    sys.exit(main())

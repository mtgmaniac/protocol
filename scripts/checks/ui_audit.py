"""UI unification audit (docs/UI_UNIFY.md). Read-only; prints markdown.

    python scripts/checks/ui_audit.py [--section fonts|colors|textures|all] [--summary]

Scans the live UI code (scripts/ui, scripts/battle, scripts/autoloads, the .tscn
scenes) for:
  fonts     font files loaded and every font-size site (call + size expression)
  colors    hardcoded colors outside the theme tokens: Color("hex"), Color(r,g,b),
            named Color.X (TRANSPARENT/WHITE as modulate are listed separately),
            .tscn color / modulate values
  textures  texture_filter settings that are not NEAREST, and TextureRects that
            stretch (possible non-integer scaling)
The token owner, scripts/ui/pixel_ui.gd, and the theme mirror are excluded from
the color scan: they ARE the tokens. Debug, sim and check scripts are excluded.
"""
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT_DIRS = ["scripts/ui", "scripts/battle", "scripts/autoloads", "scripts/units", "scripts/resources"]
SCENE_DIRS = ["scenes"]
TOKEN_FILES = {"scripts/ui/pixel_ui.gd"}
# Not UI: game logic.
COLOR_SKIP = {"scripts/battle/combat_manager.gd", "scripts/battle/battle_engine.gd"}
# Allowed classes, reported apart from the real hardcoded colors:
#  opacity  Color(1, 1, 1, a) / Color.WHITE / Color.BLACK used as a modulate or
#           identity value: an opacity or a no-op, not a color
#  dice     3D dice materials and die base colors (dice colors are constant by
#           rule, and the dice rendering is out of scope for UI passes)
OPACITY = re.compile(r'Color\(\s*1(\.0+)?\s*,\s*1(\.0+)?\s*,\s*1(\.0+)?\s*(,\s*[0-9.]+)?\s*\)|Color\.(WHITE|BLACK)\b|Color\(\s*0(\.0+)?\s*,\s*0(\.0+)?\s*,\s*0(\.0+)?\s*,\s*0(\.0+)?\s*\)')
DICE_FILES = {"scripts/battle/dice_tray_3d.gd"}

COLOR_HEX = re.compile(r'Color\("#?[0-9A-Fa-f]{6,8}"\)')
COLOR_NUM = re.compile(r'Color\(\s*-?[0-9.]+\s*,\s*-?[0-9.]+\s*,\s*-?[0-9.]+(\s*,\s*-?[0-9.]+)?\s*\)')
COLOR_NAMED = re.compile(r'\bColor\.(WHITE|BLACK|RED|GREEN|BLUE|YELLOW|GRAY|CYAN|MAGENTA|ORANGE)\b')
TSCN_COLOR = re.compile(r'^\s*([a-z_/]*(color|modulate)[a-z_/]*)\s*=\s*(Color\([^)]*\))', re.M)

FONT_SITES = [
    ("add_theme_font_size_override", re.compile(r'add_theme_font_size_override\(\s*"font_size"\s*,\s*([^)\n]+)\)')),
    ("scale_font_size", re.compile(r'scale_font_size\(([^)\n]+)\)')),
    ("text_px", re.compile(r'text_px\(([^)\n]+)\)')),
    ("style_label", re.compile(r'style_label\(\s*\w+\s*,\s*([^,\n]+),')),
    ("style_button(size)", re.compile(r'style_button\(\s*\w+\s*,[^,\n]+,[^,\n]+,\s*([^,)\n]+)')),
    ("ui button size", re.compile(r'style_ui_(?:primary|secondary)_button\(\s*[\w.]+\s*,\s*([^,)\n]+)\)')),
    ("font_size =", re.compile(r'\bfont_size\s*=\s*([^\n#]+)')),
    ("_make_*label(size)", re.compile(r'_make_(?:pixel_|wrap_|centered_)?label\([^,\n]+,\s*([A-Z_0-9]+|\d+)')),
]
FONT_LOADS = re.compile(r'(load|preload)\("([^"]+\.(?:ttf|otf|fnt|tres|res))"\)')
FONT_APPLY = [
    ("apply_pixel_font (m5x7)", re.compile(r'apply_pixel_font\(')),
    ("style_battle_text (Battle Block)", re.compile(r'style_battle_text\(')),
    ("get_battle_font (Battle Block)", re.compile(r'get_battle_font\(')),
    ("get_pixel_font (m5x7)", re.compile(r'get_pixel_font\(')),
    ("add_theme_font_override", re.compile(r'add_theme_font_override\(')),
]

FILTER_NOT_NEAREST = re.compile(r'TEXTURE_FILTER_(LINEAR\w*|NEAREST_WITH_MIPMAPS\w*)')
TSCN_FILTER = re.compile(r'^texture_filter\s*=\s*([2-6])', re.M)
STRETCH = re.compile(r'stretch_mode\s*=\s*(TextureRect\.)?(STRETCH_SCALE|STRETCH_KEEP_ASPECT\w*|0|5|6)\b|expand_mode\s*=\s*(TextureRect\.)?EXPAND_\w+')


def files(dirs, ext):
    out = []
    for d in dirs:
        out.extend(sorted((ROOT / d).rglob(f"*{ext}")))
    return [p for p in out if "debug" not in p.parts]


def rel(p):
    return p.relative_to(ROOT).as_posix()


def is_code_line(line):
    s = line.strip()
    return s and not s.startswith("#")


def fonts(summary):
    print("### Font files\n")
    for f in sorted((ROOT / "assets/fonts").glob("*")):
        if f.suffix in (".ttf", ".otf", ".fnt"):
            print(f"- `{rel(f)}`")
    print()
    loads = defaultdict(list)
    applies = Counter()
    apply_files = defaultdict(Counter)
    sites = defaultdict(list)
    for p in files(SCRIPT_DIRS, ".gd"):
        for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
            if not is_code_line(line):
                continue
            for m in FONT_LOADS.finditer(line):
                if any(k in m.group(2) for k in ("font", ".fnt", ".ttf")):
                    loads[m.group(2)].append(f"{rel(p)}:{n}")
            for name, rx in FONT_APPLY:
                c = len(rx.findall(line))
                if c:
                    applies[name] += c
                    apply_files[name][rel(p)] += c
            for name, rx in FONT_SITES:
                for m in rx.finditer(line):
                    sites[rel(p)].append((n, name, m.group(1).strip()))
    print("### Font loads (by path)\n")
    for path, where in sorted(loads.items()):
        print(f"- `{path}`: {len(where)} ({', '.join(where[:6])}{' ...' if len(where) > 6 else ''})")
    print("\n### Font application calls (counts)\n")
    for name, count in applies.most_common():
        per = ", ".join(f"{f.split('/')[-1]} {c}" for f, c in apply_files[name].most_common())
        print(f"- {name}: **{count}** ({per})")
    print("\n### Font size sites, per file\n")
    total = 0
    exprs = Counter()
    for f in sorted(sites):
        total += len(sites[f])
        for _, _, e in sites[f]:
            exprs[e] += 1
    print(f"Total size sites: **{total}** in {len(sites)} files.\n")
    print("| file | sites | size expressions (count) |\n|---|---|---|")
    for f in sorted(sites, key=lambda k: -len(sites[k])):
        c = Counter(e for _, _, e in sites[f])
        print(f"| `{f}` | {len(sites[f])} | {', '.join(f'`{e}` {k}' for e, k in c.most_common(8))}{' ...' if len(c) > 8 else ''} |")
    if not summary:
        print("\n<details><summary>Every font size site (file:line, call, size)</summary>\n")
        for f in sorted(sites):
            for n, name, e in sites[f]:
                print(f"- `{f}:{n}` {name} `{e}`")
        print("\n</details>")


def colors(summary):
    by_file = defaultdict(list)
    for p in files(SCRIPT_DIRS, ".gd"):
        r = rel(p)
        if r in TOKEN_FILES or r in COLOR_SKIP:
            continue
        for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
            if not is_code_line(line):
                continue
            for rx, kind in ((COLOR_HEX, "hex"), (COLOR_NUM, "rgb"), (COLOR_NAMED, "named")):
                for m in rx.finditer(line):
                    if r in DICE_FILES:
                        kind = "dice"
                    elif OPACITY.fullmatch(m.group(0)) or OPACITY.match(m.group(0)):
                        kind = "opacity"
                    by_file[r].append((n, kind, m.group(0)))
    for p in files(SCENE_DIRS, ".tscn"):
        text = p.read_text(encoding="utf-8")
        for m in TSCN_COLOR.finditer(text):
            n = text[:m.start()].count("\n") + 1
            by_file[rel(p)].append((n, "tscn " + m.group(1), m.group(3)))
    total = sum(len(v) for v in by_file.values())
    kinds = Counter(k.split(" ")[0] for v in by_file.values() for _, k, _ in v)
    real = total - kinds.get("opacity", 0) - kinds.get("dice", 0)
    print(f"**Real hardcoded colors: {real}** (excluding the allowed classes: opacity {kinds.get('opacity', 0)}, dice {kinds.get('dice', 0)}).\n")
    print(f"All color literal sites: **{total}** in {len(by_file)} files "
          f"({', '.join(f'{k} {c}' for k, c in kinds.most_common())}). "
          "`pixel_ui.gd` (the token owner) and `theme_overload.tres` (its mirror) are excluded.\n")
    print("| file | sites | kinds |\n|---|---|---|")
    for f in sorted(by_file, key=lambda k: -len(by_file[k])):
        c = Counter(k.split(" ")[0] for _, k, _ in by_file[f])
        print(f"| `{f}` | {len(by_file[f])} | {', '.join(f'{k} {v}' for k, v in c.most_common())} |")
    if not summary:
        print("\n<details><summary>Every hardcoded color (file:line, kind, value)</summary>\n")
        for f in sorted(by_file):
            for n, k, v in by_file[f]:
                print(f"- `{f}:{n}` {k} `{v}`")
        print("\n</details>")
    return total


def textures(summary):
    hits = []
    for p in files(SCRIPT_DIRS, ".gd"):
        for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
            if not is_code_line(line):
                continue
            m = FILTER_NOT_NEAREST.search(line)
            if m:
                hits.append((rel(p), n, "filter " + m.group(0)))
            m = STRETCH.search(line)
            if m:
                hits.append((rel(p), n, "stretch " + m.group(0).split("=")[-1].strip()))
    for p in files(SCENE_DIRS, ".tscn"):
        text = p.read_text(encoding="utf-8")
        for m in TSCN_FILTER.finditer(text):
            n = text[:m.start()].count("\n") + 1
            hits.append((rel(p), n, f"filter enum {m.group(1)} (not NEAREST)"))
        for m in re.finditer(r'^(stretch_mode|expand_mode)\s*=\s*(\d)', text, re.M):
            n = text[:m.start()].count("\n") + 1
            hits.append((rel(p), n, f"{m.group(1)} {m.group(2)}"))
    print(f"Total: **{len(hits)}** sites (project default canvas filter: see project.godot).\n")
    c = Counter(h[0] for h in hits)
    print("| file | sites |\n|---|---|")
    for f, k in c.most_common():
        print(f"| `{f}` | {k} |")
    if not summary:
        print("\n<details><summary>Every site</summary>\n")
        for f, n, k in hits:
            print(f"- `{f}:{n}` {k}")
        print("\n</details>")


if __name__ == "__main__":
    args = sys.argv[1:]
    section = "all"
    if "--section" in args:
        section = args[args.index("--section") + 1]
    summary = "--summary" in args
    if section in ("fonts", "all"):
        print("## Fonts\n")
        fonts(summary)
        print()
    if section in ("colors", "all"):
        print("## Hardcoded colors\n")
        colors(summary)
        print()
    if section in ("textures", "all"):
        print("## Textures and icons (filtering, scaling)\n")
        textures(summary)
        print()

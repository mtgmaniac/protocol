#!/usr/bin/env python3
"""Capitalization-law gate (Polish Build A, ruled by Kev 2026-07-14).

The law:
  ALL CAPS      - major alerts, page headings, buttons, small metadata labels,
                  unit callsigns on battle cards, keyword names as chips/headers.
  Title Case    - ability names and other proper nouns, wherever they appear.
  Sentence case - ability body text, lore copy, help copy, and keyword mentions
                  inline in ability text ("applies burn", never "applies BURN").

WHAT THIS GATE ENFORCES (the mechanical subset — everything else needs eyes):
  1. Data JSON body text (eff strings, descs, blurbs, keyword defs, primer
     lines) must not contain an inline ALL-CAPS keyword token ("BURN").
  2. Data JSON body text must not be entirely uppercase.
  3. Name fields (abilities, gear, items, relics, heroes, evolutions, keyword
     terms) must be Title Case: not all-lower, not all-upper. (Which words
     get capitals inside the name needs eyes; the gate only catches the two
     mechanical failure shapes.)
  4. .tscn authored `text` on Button nodes must be ALL CAPS.
  5. .gd source: no `.to_upper()` on a CONSTANT string literal
     ("FOO".to_upper() is authoring laziness — author the caps).

NOT gate-enforceable (needs eyes, listed for honesty):
  - Whether a given Label is a heading vs body (tier is semantic).
  - Title Case word-by-word correctness ("Field patch" passes mechanically).
  - .gd string literals assigned to labels (too many false positives to gate).
  - Hint-tier copy consistency across screens.

Exit 0 = pass, 1 = violations (printed one per line).
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "raw"
SCENES = ROOT / "scenes"
SCRIPTS = ROOT / "scripts"

# Keyword vocabulary that must stay lowercase inline in body text. Includes the
# display term for every entry in keywords.data.json plus effect words that read
# as keywords in copy. "ward" is excluded (internal field; displayed Firewall).
KEYWORDS = [
    "burn", "mark", "jam", "freeze", "cloak", "taunt", "pierce", "chain",
    "execute", "breach", "leech", "spike", "rewrite", "hijack", "siphon",
    "firewall", "detonate", "shield", "heal", "revive",
]
_KEYWORD_CAPS = re.compile(r"\b(" + "|".join(k.upper() for k in KEYWORDS) + r")\b")

# A leading ALL-CAPS "LABEL:" is the keyword-as-header form (primers: "BURN:
# takes damage...") — legal per the law ("keyword names when shown as
# chips/headers"). Stripped before the body scan.
_HEADER_LABEL = re.compile(r"^[A-Z][A-Z0-9 '\-]*:\s*")

# Title-Case keyword INLINE in body text ("applies Burn") is the systematic
# authoring drift this gate exists for — keyword mentions inline are lowercase.
# Sentence-INITIAL capitals are correct sentence case and skipped. Inflected
# forms are enumerated (Jammed, Frozen, Rewrites, Burning...).
_TITLE_FORMS = {
    "burn": "Burn|Burns|Burned|Burning", "mark": "Mark|Marks|Marked|Marking",
    "jam": "Jam|Jams|Jammed|Jamming", "freeze": "Freeze|Freezes|Froze|Frozen|Freezing",
    "cloak": "Cloak|Cloaks|Cloaked|Cloaking", "taunt": "Taunt|Taunts|Taunted|Taunting",
    "pierce": "Pierce|Pierces|Pierced|Piercing", "chain": "Chain|Chains|Chained|Chaining",
    "execute": "Execute|Executes|Executed|Executing",
    "breach": "Breach|Breaches|Breached|Breaching",
    "leech": "Leech|Leeches|Leeched|Leeching", "spike": "Spike|Spikes|Spiked",
    "rewrite": "Rewrite|Rewrites|Rewritten|Rewrote",
    "hijack": "Hijack|Hijacks|Hijacked|Hijacking",
    "siphon": "Siphon|Siphons|Siphoned|Siphoning",
    "firewall": "Firewall|Firewalls|Firewalled",
    "detonate": "Detonate|Detonates|Detonated|Detonating",
    "shield": "Shield|Shields|Shielded", "heal": "Heal|Heals|Healed|Healing",
    "revive": "Revive|Revives|Revived",
}
_TITLE_INLINE = re.compile(r"\b(" + "|".join(_TITLE_FORMS.values()) + r")\b")
# Sentence starts: string start or after ./!/?/: (+ whitespace). A capital
# there is grammar, not keyword emphasis.
_SENTENCE_START = re.compile(r"(?:^|[.!?:])\s*$")

# Proper-noun phrases that legally contain a keyword word (band-vocab-style
# exemption: names stay as authored). Checked as whole phrases around a match.
PROPER_NOUN_PHRASES = [
    "Spike Guard",     # hero name
    "Surge Revive",    # Splice Medic ability name
    "Signal Jam",      # relic name
    "Chain Reaction",  # relic name
]

# Body-text fields per data file: (filename, iterator over (context, text)).
# Names are checked separately via NAME_FIELDS.

# ALL-CAPS tokens that are legal inside body text (proper nouns / initialisms /
# stat words that ARE metadata even mid-sentence). Keep this list short and
# commented — every entry is a ruling, not a convenience.
ALLOWED_CAPS_TOKENS = {
    "HP", "XP", "AOE", "ECM", "EMP", "AI", "D20", "FW",
}

# Explicit per-string exemptions (exact match) for authored copy that the law
# permits in caps (e.g. an alert word inside a primer). Add sparingly.
EXEMPT_STRINGS: set[str] = set()


def _walk_body_and_names():
    """Yield ("body"|"name", context, text) for every authored player-facing
    string in the data JSON files."""
    def hero_stream(d):
        for h in d.get("heroes", []):
            hid = h.get("id", "?")
            yield "name", f"heroes:{hid}.name", h.get("name", "")
            yield "body", f"heroes:{hid}.pickerBlurb", h.get("pickerBlurb", "")
            for a in h.get("abilities", []):
                yield "name", f"heroes:{hid}.ability:{a.get('name','?')}", a.get("name", "")
                yield "body", f"heroes:{hid}.ability:{a.get('name','?')}.eff", a.get("eff", "")
            for e in h.get("evolutions", []):
                eid = e.get("id", "?")
                yield "name", f"heroes:{hid}.evo:{eid}.name", e.get("name", "")
                yield "body", f"heroes:{hid}.evo:{eid}.focus", e.get("focus", "")
                for a in e.get("abilities", []):
                    yield "name", f"heroes:{hid}.evo:{eid}.ability:{a.get('name','?')}", a.get("name", "")
                    yield "body", f"heroes:{hid}.evo:{eid}.ability:{a.get('name','?')}.eff", a.get("eff", "")
                for dr in e.get("directives", []):
                    yield "name", f"heroes:{hid}.evo:{eid}.directive:{dr.get('name','?')}", dr.get("name", "")
                    yield "body", f"heroes:{hid}.evo:{eid}.directive:{dr.get('name','?')}.desc", dr.get("desc", "")

    def enemy_stream(d):
        for kit, zones in d.get("enemyAbilities", {}).items():
            for zone, a in zones.items():
                if not isinstance(a, dict):
                    continue
                yield "name", f"enemies:{kit}.{zone}.name", a.get("name", "")
                yield "body", f"enemies:{kit}.{zone}.eff", a.get("eff", "")

    def flat_stream(d, list_key, prefix):
        for entry in d.get(list_key, []):
            eid = entry.get("id", entry.get("name", "?"))
            yield "name", f"{prefix}:{eid}.name", entry.get("name", "")
            yield "body", f"{prefix}:{eid}.desc", entry.get("desc", entry.get("description", ""))

    def keyword_stream(d):
        for k in d.get("keywords", []):
            yield "name", f"keywords:{k.get('id','?')}.term", k.get("term", "")
            yield "body", f"keywords:{k.get('id','?')}.def", k.get("def", "")

    def primer_stream(d):
        for p in d.get("primers", []):
            pid = p.get("id", "?")
            yield "body", f"primers:{pid}.text", p.get("text", p.get("line", ""))

    streams = [
        ("heroes.data.json", hero_stream),
        ("enemies.data.json", enemy_stream),
        ("gear.data.json", lambda d: flat_stream(d, "gear", "gear")),
        ("items.data.json", lambda d: flat_stream(d, "items", "items")),
        ("relics.data.json", lambda d: flat_stream(d, "relics", "relics")),
        ("keywords.data.json", keyword_stream),
        ("primers.data.json", primer_stream),
    ]
    for fname, stream in streams:
        path = DATA / fname
        if not path.exists():
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        # relics.data.json may be a bare list
        if isinstance(data, list):
            data = {"relics": data}
        for kind, ctx, text in stream(data):
            if text:
                yield kind, f"{fname} :: {ctx}", str(text)


def _letters(s: str) -> str:
    return "".join(ch for ch in s if ch.isalpha())


def check_data() -> list[str]:
    problems = []
    for kind, ctx, text in _walk_body_and_names():
        if text in EXEMPT_STRINGS:
            continue
        letters = _letters(text)
        if not letters:
            continue
        if kind == "body":
            body = _HEADER_LABEL.sub("", text)  # "BURN: ..." header form is legal
            for m in _KEYWORD_CAPS.finditer(body):
                problems.append(f"[caps-in-body] {ctx}: keyword '{m.group(1)}' must be lowercase inline -> {text!r}")
            for m in _TITLE_INLINE.finditer(body):
                if _SENTENCE_START.search(body[:m.start()]):
                    continue  # sentence-initial capital = correct sentence case
                around = body[max(0, m.start() - 24):m.end() + 24]
                if any(ph in around for ph in PROPER_NOUN_PHRASES):
                    continue
                problems.append(
                    f"[titlecase-keyword] {ctx}: '{m.group(1)}' inline must be lowercase -> {text!r}")
            body_letters = _letters(body)
            if body_letters and body_letters.isupper() and len(body_letters) > 3:
                problems.append(f"[shouting-body] {ctx}: body text is ALL CAPS -> {text!r}")
        else:  # name -> Title Case (mechanical shapes only)
            if letters.isupper():
                problems.append(f"[allcaps-name] {ctx}: name must be Title Case -> {text!r}")
            elif letters.islower():
                problems.append(f"[lowercase-name] {ctx}: name must be Title Case -> {text!r}")
    return problems


_TSCN_NODE = re.compile(r'^\[node name="(?P<name>[^"]+)" type="(?P<type>[^"]+)"', re.M)


def check_tscn_buttons() -> list[str]:
    """Authored `text` on Button nodes must be ALL CAPS (letters only judged)."""
    problems = []
    for tscn in SCENES.rglob("*.tscn"):
        current_node = ("?", "?")
        for line in tscn.read_text(encoding="utf-8").splitlines():
            m = _TSCN_NODE.match(line)
            if m:
                current_node = (m.group("name"), m.group("type"))
                continue
            if line.startswith("text = "):
                text = line[len("text = "):].strip().strip('"')
                if text in EXEMPT_STRINGS:
                    continue
                letters = _letters(text)
                if not letters:
                    continue
                if current_node[1] == "Button" and not letters.isupper():
                    problems.append(
                        f"[button-caps] {tscn.relative_to(ROOT)} node '{current_node[0]}': "
                        f"button text must be ALL CAPS -> {text!r}")
    return problems


_CONST_UPPER = re.compile(r'"([^"\\]*[a-z][^"\\]*)"\.to_upper\(\)')


def check_gd_const_upper() -> list[str]:
    """A string LITERAL passed through .to_upper() is one-off constant behavior —
    author the string in caps instead. Dynamic text (vars) is fine."""
    problems = []
    for gd in SCRIPTS.rglob("*.gd"):
        if gd.parts[-2] == "debug":
            continue
        for i, line in enumerate(gd.read_text(encoding="utf-8").splitlines(), 1):
            m = _CONST_UPPER.search(line)
            if m:
                problems.append(
                    f"[const-to-upper] {gd.relative_to(ROOT)}:{i}: author the caps -> {m.group(1)!r}.to_upper()")
    return problems


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    problems = check_data() + check_tscn_buttons() + check_gd_const_upper()
    for p in problems:
        print("  " + p)
    if problems:
        print(f"[CAPS_LAW] FAIL - {len(problems)} violation(s)")
        return 1
    print("[CAPS_LAW] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())

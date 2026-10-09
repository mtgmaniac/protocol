#!/usr/bin/env python3
"""Balance sim gate, two tiers (G-58, Kev 2026-10-09).

The sim is byte-deterministic and the batch config is pinned, so an UNCHANGED
tree reproduces the pins exactly. That makes two different instruments:

  Tier 1, the TRIPWIRE: 300 pinned runs per policy, every full gate.
    Any move at all means combat changed. The SIZE of a move on 300 runs is
    unreliable (about 60 runs per operation: the same change reads -15 to +19
    points from one block of 300 to the next, G-57), so it is never judged.

  Tier 2, the SIZE CHECK: 1,500 pinned runs, run only for a policy whose
    tripwire moved. A move beyond 8 points on an operation or 4 overall needs
    Kev's sign-off (the ceremony, docs/INVARIANTS.md #9).

Both tiers run for `l1` (first evolutions) and `l1_evo2` (second evolutions).

  python scripts/sim/ci_smoke.py                   # the two-tier check
  python scripts/sim/ci_smoke.py --update-baseline # re-pin all four pins
  python scripts/sim/ci_smoke.py --size-break      # the deliberate break (sim_size_break gate)

Exit codes: 0 = no move, or a move inside the size line · 3 = beyond the size
line (ceremony) · 1 = the pins are missing or were not written together.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SIM_DIR = Path(__file__).resolve().parent
# The l1 tripwire pin keeps its old name and shape: hooks and docs know it.
BASELINE = SIM_DIR / "baseline.json"
# The l1_evo2 tripwire pin and both size pins, written together with BASELINE.
PINS = SIM_DIR / "baseline_pins.json"

# Pinned batch config. Changing any of these invalidates every pin.
CI_SEED_BASE = 900000
POLICIES = ["l1", "l1_evo2"]
TRIPWIRE_RUNS = 300
SIZE_RUNS = 1500

# The ceremony line, judged on the size check only (clear-rate points). Set
# from the measured spread at 1,500 runs (G-57): 2 to 4 points per operation,
# under 2 overall. Loosening either needs BASELINE-APPROVED-BY-KEV
# (threshold_guard, INVARIANTS #13).
SIZE_OP_PTS = 8.0
SIZE_OVERALL_PTS = 4.0

# The deliberate break (scripts/checks/sim_size_break.py): a real change of
# about 10 points on one operation, which the size check must catch. +8% enemy
# damage in the Hive measured -9.8 / -8.9 / -10.3 points of Hive clear rate on
# three 1,500-run seed sets (900000, 500000, 700000; G-58).
SIZE_BREAK_OP = "hive"
SIZE_BREAK_TUNING = "enemy_dmg_scalar@hive=1.08"

OP_NAMES = {"facility": "Facility", "hive": "Hive", "veil": "Veil",
            "voidCirclet": "Signal Purge", "stellarMenagerie": "Mantle Hunt"}


def build_metrics(runs: int, policy: str = "l1", tuning: str = "") -> dict:
    # Batch into results/ (the sim writes reliably to project-relative paths;
    # a system-temp dir outside the project breaks its FileAccess).
    name = "_ci_smoke"
    out_dir = ROOT / "results" / name
    if out_dir.exists():
        shutil.rmtree(out_dir)
    cmd = [sys.executable, str(ROOT / "scripts/sim/batch.py"),
           "--name", name, "--runs", str(runs), "--policy", policy,
           "--seed-base", str(CI_SEED_BASE)]
    if tuning:
        cmd += ["--tuning", tuning]
    subprocess.run(cmd, check=True, capture_output=True, text=True)
    out = subprocess.run([sys.executable, str(ROOT / "scripts/sim/analyze.py"),
                          str(out_dir), "--metrics"],
                         check=True, capture_output=True, text=True)
    shutil.rmtree(out_dir, ignore_errors=True)
    return json.loads(out.stdout)


def digest(metrics: dict) -> str:
    return hashlib.sha256(json.dumps(metrics, sort_keys=True).encode("utf-8")).hexdigest()


def slim(metrics: dict) -> dict:
    """What a size pin keeps: the rates the size line is judged on."""
    return {key: metrics[key] for key in ("runs", "policy", "overall_clear", "clear_by_op", "clear_by_hero")}


def load_pins() -> dict:
    """{'tripwire': {policy: metrics}, 'size': {policy: metrics}}. Raises
    ValueError when a pin is missing or the two files were not written
    together (re-pinning only the tripwire would hide a change from the size
    check for good)."""
    if not BASELINE.exists() or not PINS.exists():
        raise ValueError(f"missing {BASELINE.name} or {PINS.name}; run ci_smoke.py --update-baseline")
    base = json.loads(BASELINE.read_text(encoding="utf-8"))
    pins = json.loads(PINS.read_text(encoding="utf-8"))
    if pins.get("pinned_with") != digest(base):
        raise ValueError(f"{PINS.name} was not written together with {BASELINE.name}; "
                         "run ci_smoke.py --update-baseline")
    tripwire = {"l1": base}
    tripwire.update(pins.get("tripwire", {}))
    size = pins.get("size", {})
    for policy in POLICIES:
        if policy not in tripwire or policy not in size:
            raise ValueError(f"no pin for policy {policy}; run ci_smoke.py --update-baseline")
        if int(tripwire[policy].get("runs", 0)) != TRIPWIRE_RUNS or int(size[policy].get("runs", 0)) != SIZE_RUNS:
            raise ValueError(f"the {policy} pins were made with another run count; run ci_smoke.py --update-baseline")
    return {"tripwire": tripwire, "size": size}


def pts(now: float, pin: float) -> float:
    return round((now - pin) * 100.0, 2)


def tripwire_moves(cur: dict, pin: dict) -> list:
    """Every pinned figure that differs. Empty = the runs reproduced exactly."""
    moves = []
    if cur.get("overall_clear") != pin.get("overall_clear"):
        moves.append("overall")
    for section, label in (("clear_by_op", "operation"), ("clear_by_hero", "hero"), ("content_lift", "content")):
        a, b = cur.get(section, {}), pin.get(section, {})
        for key in sorted(set(a) | set(b)):
            if a.get(key) != b.get(key):
                moves.append(f"{label} {key}")
    if not moves and cur != pin:
        moves.append("run metadata")
    return moves


def size_flags(cur: dict, pin: dict) -> list:
    """(label, pin, now, move, line) for every figure beyond the size line."""
    flags = []
    move = pts(cur["overall_clear"], pin["overall_clear"])
    if abs(move) > SIZE_OVERALL_PTS:
        flags.append(("overall", pin["overall_clear"], cur["overall_clear"], move, SIZE_OVERALL_PTS))
    for op in sorted(set(cur["clear_by_op"]) | set(pin["clear_by_op"])):
        a, b = cur["clear_by_op"].get(op, 0.0), pin["clear_by_op"].get(op, 0.0)
        move = pts(a, b)
        if abs(move) > SIZE_OP_PTS:
            flags.append((op, b, a, move, SIZE_OP_PTS))
    return flags


def print_table(cur: dict, pin: dict, judged: bool) -> None:
    print(f"   {'':<18}{'pin':>9}{'now':>9}{'move':>8}")
    rows = [("overall", pin["overall_clear"], cur["overall_clear"], SIZE_OVERALL_PTS)]
    rows += [(op, pin["clear_by_op"].get(op, 0.0), cur["clear_by_op"].get(op, 0.0), SIZE_OP_PTS)
             for op in sorted(pin["clear_by_op"])]
    for label, b, a, line in rows:
        move = pts(a, b)
        mark = f"  <-- BEYOND {line:g}" if judged and abs(move) > line else ""
        print(f"   {OP_NAMES.get(label, label):<18}{b:>9.4f}{a:>9.4f}{move:>+8.1f}{mark}")


def run_two_tier() -> int:
    try:
        pins = load_pins()
    except ValueError as exc:
        print(f"   FAIL: {exc}")
        return 1

    print(f"── balance sim, tier 1: tripwire ({TRIPWIRE_RUNS} pinned runs per policy) ...", flush=True)
    moved = []
    for policy in POLICIES:
        cur = build_metrics(TRIPWIRE_RUNS, policy)
        moves = tripwire_moves(cur, pins["tripwire"][policy])
        if moves:
            moved.append(policy)
            print(f"\n   {policy}: MOVED ({len(moves)} pinned figure(s): {', '.join(moves[:6])}"
                  f"{', ...' if len(moves) > 6 else ''})")
            print_table(cur, pins["tripwire"][policy], False)
        else:
            print(f"   {policy}: no move (overall {cur['overall_clear']:.4f})", flush=True)
    if not moved:
        print("   tripwire: no move. The pinned runs reproduced exactly, so combat is unchanged.")
        return 0
    print(
        "\n   TRIPWIRE MOVED. Any move at all means combat changed: an unchanged tree\n"
        "   reproduces these runs exactly. Do NOT read the size of the move above:\n"
        f"   on {TRIPWIRE_RUNS} runs it is unreliable (about {TRIPWIRE_RUNS // 5} runs per operation; the same\n"
        "   change reads -15 to +19 points from one block to the next, G-57).\n"
        "   The size check below is the one that judges it.",
        flush=True,
    )

    beyond = []
    for policy in moved:
        print(f"\n── balance sim, tier 2: size check ({SIZE_RUNS} pinned runs, {policy}) ...", flush=True)
        cur = build_metrics(SIZE_RUNS, policy)
        print_table(cur, pins["size"][policy], True)
        for label, _b, _a, move, line in size_flags(cur, pins["size"][policy]):
            beyond.append(f"{policy} {OP_NAMES.get(label, label)} {move:+.1f} (line {line:g})")
    if beyond:
        print(
            "\n   CEREMONY: a real move beyond the size line ({}).\n"
            "   A human signs off on a move this size (docs/INVARIANTS.md #9).\n"
            "   Do NOT run ci_smoke.py --update-baseline; the commit that re-pins must\n"
            "   contain BASELINE-APPROVED-BY-KEV or the commit-msg hook aborts it."
            .format("; ".join(beyond))
        )
        return 3
    print(
        f"\n   Combat changed, inside the size line ({SIZE_OP_PTS:g} per operation, {SIZE_OVERALL_PTS:g} overall).\n"
        "   If the change is intended, re-pin: python scripts/sim/ci_smoke.py --update-baseline\n"
        "   (until then every full gate pays for this size check)."
    )
    return 0


def update_baseline() -> int:
    """Re-pin all four pins together. The commit-msg hook judges the size pins
    against HEAD and asks for Kev's token beyond the line."""
    tripwire, size = {}, {}
    for policy in POLICIES:
        print(f"[CI] pinning {policy}: {TRIPWIRE_RUNS} runs ...", flush=True)
        tripwire[policy] = build_metrics(TRIPWIRE_RUNS, policy)
        print(f"[CI] pinning {policy}: {SIZE_RUNS} runs ...", flush=True)
        size[policy] = slim(build_metrics(SIZE_RUNS, policy))
    BASELINE.write_text(json.dumps(tripwire["l1"], indent=2) + "\n", encoding="utf-8", newline="\n")
    pins = {
        "$comment": "Written by ci_smoke.py --update-baseline, together with baseline.json (the l1 tripwire). "
                    "Never edit by hand; pinned_with ties the two files.",
        "seed_base": CI_SEED_BASE,
        "pinned_with": digest(tripwire["l1"]),
        "tripwire": {policy: tripwire[policy] for policy in POLICIES if policy != "l1"},
        "size": size,
    }
    PINS.write_text(json.dumps(pins, indent=2) + "\n", encoding="utf-8", newline="\n")
    for policy in POLICIES:
        print(f"[CI] {policy}: tripwire overall {tripwire[policy]['overall_clear']:.1%}, "
              f"size pin overall {size[policy]['overall_clear']:.1%}")
    print(f"[CI] pins updated: {BASELINE.name}, {PINS.name}")
    return 0


def size_break(reference: dict = None) -> dict:
    """The l1 size batch with the deliberate break applied, judged against the
    size pin (or `reference`). Returns {'cur', 'pin', 'flags'}."""
    pin = reference if reference is not None else load_pins()["size"]["l1"]
    cur = build_metrics(SIZE_RUNS, "l1", SIZE_BREAK_TUNING)
    return {"cur": cur, "pin": pin, "flags": size_flags(cur, pin)}


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    ap = argparse.ArgumentParser(description="Balance sim gate: tripwire, then size check")
    ap.add_argument("--update-baseline", action="store_true", help="re-pin all four pins together")
    ap.add_argument("--size-break", action="store_true",
                    help="run the l1 size check with the deliberate break (exits 3 when it is caught)")
    args = ap.parse_args()
    if args.update_baseline:
        return update_baseline()
    if args.size_break:
        try:
            result = size_break()
        except ValueError as exc:
            print(f"   FAIL: {exc}")
            return 1
        print_table(result["cur"], result["pin"], True)
        return 3 if result["flags"] else 0
    return run_two_tier()


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Deliberate breaks for the two-tier sim gate (G-58, Kev 2026-10-09).

Part A, instant, on made-up figures: the size line (8 points per operation, 4
overall), the tripwire (any pinned figure that differs is a move), the tie
between the two pin files, Part B's stamp, and the commit hook agreeing with
the gate. Then five in-memory breaks, each of which must make Part A fail:

    old_line        the per-operation line back at 10 (a 9-point move passes)
    loose_overall   the overall line at 10 (a 5-point move passes)
    blind_tripwire  the tripwire never reports a move
    untied_pins     the tie between the pin files is not checked
    stale_stamp     Part B's stamp never sees a change (it would never rerun)

Part B, a REAL change run through the real size check: enemy damage in the
Hive raised by ci_smoke.SIZE_BREAK_TUNING (+8%), which costs about 10 points
of Hive clear rate (-9.8 / -8.9 / -10.3 on three seed sets, G-58). The
1,500-run size check must flag the Hive. It is compared against the size pin when the tree
still reproduces the l1 tripwire, and against a fresh clean batch when it does
not (a change in progress must not mask or fake the break).

Part B runs only when scripts/sim/ci_smoke.py or a pin file has changed since
it last passed (Kev 2026-10-09, G-59). A passing Part B writes the fingerprint
of those three files to scripts/sim/size_break_stamp.json; while the stamp
matches, Part B is skipped and the gate says so. Commit the stamp with the
change that moved it.

    python scripts/checks/sim_size_break.py              # A; B only if ci_smoke.py or the pins changed
    python scripts/checks/sim_size_break.py --real       # A + B (about 4 minutes), whatever the stamp says
    python scripts/checks/sim_size_break.py --logic-only # A only

Prints [SIM_SIZE_BREAK] PASS, exit 0; anything else is a failure.
"""
import copy
import hashlib
import json
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "sim"))
sys.path.insert(0, str(ROOT / "scripts" / "hooks"))
import ci_smoke  # noqa: E402
import baseline_ceremony  # noqa: E402

OPS = ["facility", "hive", "stellarMenagerie", "veil", "voidCirclet"]

# Part B reruns when any of these changes (G-59). The stamp holds their
# fingerprint from the last time Part B passed.
STAMP = ROOT / "scripts" / "sim" / "size_break_stamp.json"
STAMPED_FILES = [Path(ci_smoke.__file__).resolve(), ci_smoke.BASELINE, ci_smoke.PINS]
CRLF, LF, SEP = bytes([13, 10]), bytes([10]), bytes([0])


def stamp_fingerprint(files: list = None) -> str:
    """sha256 over the stamped files, line endings normalized (a checkout's
    CRLF must not read as a change)."""
    h = hashlib.sha256()
    for path in (files or STAMPED_FILES):
        h.update(Path(path).name.encode("utf-8") + SEP)
        h.update(Path(path).read_bytes().replace(CRLF, LF) + SEP)
    return h.hexdigest()


def real_leg_due(stamp: Path = None, files: list = None) -> bool:
    """True when ci_smoke.py or a pin file differs from the last passing Part B."""
    try:
        return json.loads((stamp or STAMP).read_text(encoding="utf-8"))["part_b_passed_for"] != stamp_fingerprint(files)
    except (OSError, ValueError, KeyError):
        return True


def write_stamp() -> None:
    body = json.dumps({
        "_note": "Written by scripts/checks/sim_size_break.py when its real leg (Part B) passes. Never edit by hand.",
        "files": [p.relative_to(ROOT).as_posix() for p in STAMPED_FILES],
        "part_b_passed_for": stamp_fingerprint(),
    }, indent=2)
    STAMP.write_bytes(body.encode("utf-8") + LF)


def made_up(runs: int = 1500) -> dict:
    return {
        "runs": runs, "policy": "l1", "overall_clear": 0.2600,
        "clear_by_op": {"facility": 0.3700, "hive": 0.2900, "stellarMenagerie": 0.1700, "veil": 0.2300, "voidCirclet": 0.2700},
        "clear_by_hero": {"pulse": 0.2200, "shield": 0.1900},
        "content_lift": {"gear__breach_tip": 0.336},
    }


def moved(pin: dict, section: str, key: str, points: float) -> dict:
    out = copy.deepcopy(pin)
    if section == "overall":
        out["overall_clear"] = round(out["overall_clear"] + points / 100.0, 4)
    else:
        out[section][key] = round(out[section][key] + points / 100.0, 4)
    return out


def flagged(cur: dict, pin: dict) -> list:
    return [row[0] for row in ci_smoke.size_flags(cur, pin)]


def logic_failures() -> list:
    """Every Part A check that does not hold. Empty = Part A passes."""
    bad = []

    def expect(ok: bool, what: str) -> None:
        if not ok:
            bad.append(what)

    pin = made_up()
    expect(flagged(pin, pin) == [], "an unchanged batch is inside the size line")
    expect(flagged(moved(pin, "clear_by_op", "facility", 8.0), pin) == [], "a move of exactly 8 on an operation is inside the line")
    expect(flagged(moved(pin, "clear_by_op", "facility", 8.1), pin) == ["facility"], "a move of 8.1 on an operation is beyond the line")
    expect(flagged(moved(pin, "clear_by_op", "facility", 9.0), pin) == ["facility"], "a move of 9 on an operation is beyond the line")
    expect(flagged(moved(pin, "clear_by_op", "hive", -10.0), pin) == ["hive"], "a 10-point drop on an operation is beyond the line")
    expect(flagged(moved(pin, "overall", "", 4.0), pin) == [], "a move of exactly 4 overall is inside the line")
    expect(flagged(moved(pin, "overall", "", 5.0), pin) == ["overall"], "a move of 5 overall is beyond the line")
    expect(flagged(moved(pin, "overall", "", -4.1), pin) == ["overall"], "a drop of 4.1 overall is beyond the line")

    trip = made_up(300)
    expect(ci_smoke.tripwire_moves(trip, trip) == [], "identical pinned runs are not a move")
    expect(ci_smoke.tripwire_moves(moved(trip, "clear_by_hero", "pulse", 0.33), trip) == ["hero pulse"], "one run's worth on one hero is a move")
    expect(ci_smoke.tripwire_moves(moved(trip, "clear_by_op", "veil", -1.5), trip) == ["operation veil"], "a small move on one operation is a move")
    lifted = copy.deepcopy(trip)
    lifted["content_lift"]["gear__breach_tip"] = 0.337
    expect(ci_smoke.tripwire_moves(lifted, trip) == ["content gear__breach_tip"], "a content figure that differs is a move")

    # The tie between the two pin files, on copies in a scratch folder.
    real_base, real_pins = ci_smoke.BASELINE, ci_smoke.PINS
    with tempfile.TemporaryDirectory() as scratch:
        ci_smoke.BASELINE = Path(scratch) / "baseline.json"
        ci_smoke.PINS = Path(scratch) / "baseline_pins.json"
        try:
            base = json.loads(real_base.read_text(encoding="utf-8"))
            pins = json.loads(real_pins.read_text(encoding="utf-8"))

            def loads(base_obj: dict, pins_obj: dict) -> bool:
                ci_smoke.BASELINE.write_text(json.dumps(base_obj), encoding="utf-8")
                ci_smoke.PINS.write_text(json.dumps(pins_obj), encoding="utf-8")
                try:
                    ci_smoke.load_pins()
                    return True
                except ValueError:
                    return False

            expect(loads(base, pins), "the committed pins load")
            expect(not loads(moved(base, "overall", "", 1.0), pins), "a tripwire re-pinned without the size pins is refused")
            no_evo2 = copy.deepcopy(pins)
            no_evo2["size"].pop("l1_evo2", None)
            expect(not loads(base, no_evo2), "a missing second-evolution size pin is refused")
            short = copy.deepcopy(pins)
            short["size"]["l1"]["runs"] = 300
            expect(not loads(base, short), "a size pin made with 300 runs is refused")
        finally:
            ci_smoke.BASELINE, ci_smoke.PINS = real_base, real_pins

    # Part B's stamp (G-59), on scratch copies: due with no stamp, skipped once
    # stamped, and due again when any one stamped file changes.
    with tempfile.TemporaryDirectory() as scratch:
        copies = []
        for src in STAMPED_FILES:
            dst = Path(scratch) / src.name
            dst.write_bytes(src.read_bytes())
            copies.append(dst)
        stamp = Path(scratch) / "stamp.json"
        expect(real_leg_due(stamp, copies), "with no stamp the real leg is due")
        stamp.write_text(json.dumps({"part_b_passed_for": stamp_fingerprint(copies)}), encoding="utf-8")
        expect(not real_leg_due(stamp, copies), "with a matching stamp the real leg is skipped")
        copies[0].write_bytes(copies[0].read_bytes().replace(CRLF, LF).replace(LF, CRLF))
        expect(not real_leg_due(stamp, copies), "line endings alone are not a change")
        for dst in copies:
            before = dst.read_bytes()
            dst.write_bytes(before + b"# changed")
            expect(real_leg_due(stamp, copies), f"a change to {dst.name} makes the real leg due")
            dst.write_bytes(before)
        expect(not real_leg_due(stamp, copies), "with the files put back the real leg is skipped again")

    # The commit hook must judge what the gate judges.
    expect(baseline_ceremony.digest(pin) == ci_smoke.digest(pin), "the hook's digest is the gate's")
    hook = lambda cur: baseline_ceremony.beyond_the_line({"l1": pin}, {"l1": cur}, ci_smoke.SIZE_OP_PTS, ci_smoke.SIZE_OVERALL_PTS)  # noqa: E731
    expect(hook(pin) == [], "hook: an unchanged size pin needs no token")
    expect(hook(moved(pin, "clear_by_op", "facility", 8.0)) == [], "hook: 8 on an operation needs no token")
    expect(len(hook(moved(pin, "clear_by_op", "facility", 8.1))) == 1, "hook: 8.1 on an operation needs the token")
    expect(len(hook(moved(pin, "overall", "", 4.1))) == 1, "hook: 4.1 overall needs the token")
    return bad


def with_break(name: str) -> list:
    global stamp_fingerprint
    saved = (ci_smoke.SIZE_OP_PTS, ci_smoke.SIZE_OVERALL_PTS, ci_smoke.tripwire_moves, ci_smoke.digest)
    saved_fingerprint = stamp_fingerprint
    try:
        if name == "old_line":
            ci_smoke.SIZE_OP_PTS = 10.0
        elif name == "loose_overall":
            ci_smoke.SIZE_OVERALL_PTS = 10.0
        elif name == "blind_tripwire":
            ci_smoke.tripwire_moves = lambda cur, pin: []
        elif name == "untied_pins":
            tie = json.loads(ci_smoke.PINS.read_text(encoding="utf-8"))["pinned_with"]
            ci_smoke.digest = lambda metrics: tie
        elif name == "stale_stamp":
            stamp_fingerprint = lambda files=None: "unchanged"
        return logic_failures()
    finally:
        stamp_fingerprint = saved_fingerprint
        ci_smoke.SIZE_OP_PTS, ci_smoke.SIZE_OVERALL_PTS, ci_smoke.tripwire_moves, ci_smoke.digest = saved


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:  # noqa: BLE001
        pass
    errors = []

    clean = logic_failures()
    for what in clean:
        errors.append(f"part A: {what}")
    print(f"part A: {'the size line, the tripwire, the pin tie and the hook hold' if not clean else '%d check(s) failed' % len(clean)}")
    for name in ("old_line", "loose_overall", "blind_tripwire", "untied_pins", "stale_stamp"):
        caught = with_break(name)
        if caught:
            print(f"part A: break {name} is caught ({caught[0]})")
        else:
            errors.append(f"part A: break {name} was NOT caught")

    run_real = "--logic-only" not in sys.argv and not errors
    if run_real and "--real" not in sys.argv and not real_leg_due():
        run_real = False
        print("part B: skipped. scripts/sim/ci_smoke.py and the pin files are unchanged since it last passed "
              "(scripts/sim/size_break_stamp.json). --real runs it anyway")
    if run_real:
        pins = ci_smoke.load_pins()
        tripwire = ci_smoke.build_metrics(ci_smoke.TRIPWIRE_RUNS, "l1")
        if ci_smoke.tripwire_moves(tripwire, pins["tripwire"]["l1"]):
            print("part B: the tree does not reproduce the l1 tripwire (a change is in progress); "
                  "comparing the break against a fresh clean batch, not the pin")
            reference = ci_smoke.slim(ci_smoke.build_metrics(ci_smoke.SIZE_RUNS, "l1"))
        else:
            reference = pins["size"]["l1"]
        result = ci_smoke.size_break(reference)
        op = ci_smoke.SIZE_BREAK_OP
        move = ci_smoke.pts(result["cur"]["clear_by_op"][op], reference["clear_by_op"][op])
        hit = [row[0] for row in result["flags"]]
        print(f"part B: {ci_smoke.SIZE_BREAK_TUNING} on {ci_smoke.SIZE_RUNS} runs moves {op} "
              f"{reference['clear_by_op'][op]:.4f} -> {result['cur']['clear_by_op'][op]:.4f} ({move:+.1f} points); "
              f"beyond the line: {', '.join(hit) if hit else 'nothing'}")
        if op not in hit:
            errors.append(f"part B: the size check did NOT flag {op} for a real change of about 10 points ({move:+.1f} measured)")
        others = [name for name in hit if name not in (op, "overall")]
        if others:
            errors.append(f"part B: the break touches only {op}, but the size check also flagged {', '.join(others)}")
        if not errors:
            write_stamp()
            print("part B: passed; stamp written (commit scripts/sim/size_break_stamp.json if it changed)")

    if errors:
        for line in errors:
            print(f"FAIL - {line}")
        print("[SIM_SIZE_BREAK] FAIL")
        return 1
    print("[SIM_SIZE_BREAK] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())

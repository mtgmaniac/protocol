#!/usr/bin/env bash
# Balance-sim determinism gate (Package A.5): same seed + same config must
# produce BYTE-IDENTICAL JSONL. Runs the headless sim twice and compares.
#
# Usage:   tests/sim_determinism.sh [seed]
# Godot:   override the binary with  GODOT=/path/to/godot  tests/sim_determinism.sh
set -euo pipefail

GODOT="${GODOT:-C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe}"
SCENE="res://scenes/sim/sim_main.tscn"
SEED="${1:-12345}"
ARGS="--seed ${SEED} --squad pulse,combat,shield --op facility"

OUT_DIR="results/determinism"
mkdir -p "${OUT_DIR}"

# Every policy has its own seeded decision stream — cover them all (B.2).
for POLICY in stub l0 l1; do
	A="${OUT_DIR}/seed_${SEED}_${POLICY}_a.jsonl"
	B="${OUT_DIR}/seed_${SEED}_${POLICY}_b.jsonl"
	"${GODOT}" --headless --path . "${SCENE}" -- ${ARGS} --policy "${POLICY}" --out "${A}" >/dev/null 2>&1
	"${GODOT}" --headless --path . "${SCENE}" -- ${ARGS} --policy "${POLICY}" --out "${B}" >/dev/null 2>&1
	if cmp -s "${A}" "${B}"; then
		echo "[DETERMINISM] PASS — seed ${SEED} policy ${POLICY} byte-identical ($(wc -l < "${A}") lines)"
	else
		echo "[DETERMINISM] FAIL — seed ${SEED} policy ${POLICY} differs:"
		diff "${A}" "${B}" | head -20
		exit 1
	fi
done
exit 0
